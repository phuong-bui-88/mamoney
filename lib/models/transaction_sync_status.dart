/// Enum representing the synchronization status of a transaction
enum TransactionSyncStatus {
  /// Transaction has been saved to Firestore and is synced
  synced,

  /// Transaction is pending - waiting to be synced to Firestore (offline)
  pending,

  /// Transaction is currently being synced to Firestore
  syncing,

  /// Transaction failed to sync - will be retried
  failed,
}

/// Extension to convert string to enum
extension TransactionSyncStatusExtension on String {
  TransactionSyncStatus toSyncStatus() {
    switch (this) {
      case 'synced':
        return TransactionSyncStatus.synced;
      case 'pending':
        return TransactionSyncStatus.pending;
      case 'syncing':
        return TransactionSyncStatus.syncing;
      case 'failed':
        return TransactionSyncStatus.failed;
      default:
        return TransactionSyncStatus.synced;
    }
  }
}
