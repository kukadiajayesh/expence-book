import '../models.dart';

enum OpKind { create, update, delete }

/// One change made on the device that Odoo has not seen yet.
class PendingOp {
  PendingOp(this.kind, this.id, [this.txn]);

  final OpKind kind;

  /// The transaction's id: negative until Odoo has created it, then Odoo's.
  int id;

  /// The data to send, for create and update.
  Txn? txn;

  /// Why the last attempt failed, if it did.
  String? error;

  /// True while the request is on the wire; such an op is never edited.
  bool inFlight = false;

  Map<String, dynamic> toJson() => {'kind': kind.name, 'id': id, if (txn != null) 'txn': txn!.toJson(), if (error != null) 'error': error};

  factory PendingOp.fromJson(Map<String, dynamic> j) => PendingOp(
        OpKind.values.byName(j['kind'] as String),
        j['id'] as int,
        j['txn'] == null ? null : Txn.fromJson(j['txn'] as Map<String, dynamic>),
      )..error = j['error'] as String?;
}

/// The list of unsynced changes, kept short: several edits to one
/// transaction become one request, and an add that is deleted before it syncs
/// is forgotten.
class SyncQueue {
  SyncQueue([Iterable<PendingOp> ops = const []]) : ops = [...ops];

  final List<PendingOp> ops;

  bool get isEmpty => ops.isEmpty;
  int get length => ops.length;

  bool hasOpFor(int id) => ops.any((o) => o.id == id);

  Iterable<int> idsWith(OpKind k) => ops.where((o) => o.kind == k).map((o) => o.id);

  /// Records that [t] was added (negative id) or edited.
  void upsert(Txn t) {
    final open = _editable(t.id);
    if (open != null && open.kind != OpKind.delete) {
      open.txn = t;
      open.error = null;
      return;
    }
    ops.add(PendingOp(t.id < 0 ? OpKind.create : OpKind.update, t.id, t));
  }

  /// Records a delete. Returns what is needed to take it back with [undoDelete].
  DeleteToken delete(int id) {
    final removed = <PendingOp>[];
    final open = _editable(id);
    if (open != null) {
      ops.remove(open);
      removed.add(open);
      // Never reached the server: nothing more to do.
      if (open.kind == OpKind.create) return DeleteToken(removed, null);
    }
    // If a create is in flight, this delete follows it once the real id is known.
    final added = PendingOp(OpKind.delete, id);
    ops.add(added);
    return DeleteToken(removed, added);
  }

  /// True if the delete is still queued and was taken back; false when it
  /// already reached the server, so the caller must create the record again.
  bool undoDelete(DeleteToken token) {
    final added = token.added;
    if (added != null && !ops.remove(added)) return false;
    ops.insertAll(0, token.removed);
    return true;
  }

  /// Odoo gave a new transaction its real id; later ops follow it.
  void remapId(int from, int to) {
    for (final o in ops) {
      if (o.id == from) {
        o.id = to;
        if (o.txn != null) o.txn = Txn(id: to, type: o.txn!.type, amount: o.txn!.amount, person: o.txn!.person, date: o.txn!.date, note: o.txn!.note);
      }
    }
  }

  void remove(PendingOp op) => ops.remove(op);

  /// The not-yet-sent op for [id] that may still be edited.
  PendingOp? _editable(int id) {
    for (final o in ops) {
      if (o.id == id && !o.inFlight) return o;
    }
    return null;
  }
}

class DeleteToken {
  DeleteToken(this.removed, this.added);

  final List<PendingOp> removed;
  final PendingOp? added;
}
