package app.ledger.data

import app.ledger.model.Txn
import kotlinx.serialization.Serializable
import kotlinx.serialization.Transient

enum class OpKind { Create, Update, Delete }

/** One change made on the device that Odoo has not seen yet. */
@Serializable
class PendingOp(
    val kind: OpKind,
    /** The transaction's id: negative until Odoo has created it, then Odoo's. */
    var id: Int,
    /** The data to send, for create and update. */
    var txn: Txn? = null,
    /** Why the last attempt failed, if it did. */
    var error: String? = null,
) {
    /** True while the request is on the wire; such an op is never edited. */
    @Transient
    var inFlight: Boolean = false
}

class DeleteToken(val removed: List<PendingOp>, val added: PendingOp?)

/**
 * The list of unsynced changes, kept short: several edits to one transaction become one
 * request, and an add that is deleted before it syncs is forgotten.
 */
class SyncQueue(ops: Iterable<PendingOp> = emptyList()) {
    val ops: MutableList<PendingOp> = ops.toMutableList()

    val isEmpty get() = ops.isEmpty()
    val size get() = ops.size

    fun idsWith(k: OpKind): Set<Int> = ops.filter { it.kind == k }.map { it.id }.toSet()

    /** Records that [t] was added (negative id) or edited. */
    fun upsert(t: Txn) {
        val open = editable(t.id)
        if (open != null && open.kind != OpKind.Delete) {
            open.txn = t
            open.error = null
            return
        }
        ops.add(PendingOp(if (t.id < 0) OpKind.Create else OpKind.Update, t.id, t))
    }

    /** Records a delete. Returns what is needed to take it back with [undoDelete]. */
    fun delete(id: Int): DeleteToken {
        val removed = mutableListOf<PendingOp>()
        val open = editable(id)
        if (open != null) {
            ops.remove(open)
            removed.add(open)
            // Never reached the server: nothing more to do.
            if (open.kind == OpKind.Create) return DeleteToken(removed, null)
        }
        // If a create is in flight, this delete follows it once the real id is known.
        val added = PendingOp(OpKind.Delete, id)
        ops.add(added)
        return DeleteToken(removed, added)
    }

    /**
     * True if the delete was still queued and was taken back; false when it already reached
     * the server, so the caller must create the record again.
     */
    fun undoDelete(token: DeleteToken): Boolean {
        val added = token.added
        if (added != null && !ops.remove(added)) return false
        ops.addAll(0, token.removed)
        return true
    }

    /** Odoo gave a new transaction its real id; later ops follow it. */
    fun remapId(from: Int, to: Int) {
        for (o in ops) {
            if (o.id == from) {
                o.id = to
                o.txn = o.txn?.withId(to)
            }
        }
    }

    fun remove(op: PendingOp) {
        ops.remove(op)
    }

    /** The not-yet-sent op for [id] that may still be edited. */
    private fun editable(id: Int): PendingOp? = ops.firstOrNull { it.id == id && !it.inFlight }
}
