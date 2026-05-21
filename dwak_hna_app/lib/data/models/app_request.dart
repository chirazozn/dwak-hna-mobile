enum RequestKind {
  medicine,
  product,
}

enum RequestStatus {
  waiting,
  responseReceived,
  accepted,
  ready,
  finished,
  cancelled,
}

class AppRequest {
  final int id;
  final RequestKind kind;
  final String title;
  final String pharmacyName;
  final RequestStatus status;
  final DateTime createdAt;
  final List<String> steps;
  final int activeStep;

  const AppRequest({
    required this.id,
    required this.kind,
    required this.title,
    required this.pharmacyName,
    required this.status,
    required this.createdAt,
    required this.steps,
    required this.activeStep,
  });
}

extension RequestStatusLabel on RequestStatus {
  String get label {
    switch (this) {
      case RequestStatus.waiting:
        return 'En attente';
      case RequestStatus.responseReceived:
        return 'Réponse reçue';
      case RequestStatus.accepted:
        return 'Acceptée';
      case RequestStatus.ready:
        return 'Prête';
      case RequestStatus.finished:
        return 'Terminée';
      case RequestStatus.cancelled:
        return 'Annulée';
    }
  }
}
