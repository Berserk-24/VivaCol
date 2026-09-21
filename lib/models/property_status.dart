import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Estado tipo semaforo que representa la fiabilidad de una publicacion.
/// Se actualiza a partir de los reportes de la comunidad.
enum PropertyStatus {
  verificado,
  enRevision,
  alerta,
}

extension PropertyStatusX on PropertyStatus {
  /// Texto legible para mostrar en la interfaz.
  String get label {
    switch (this) {
      case PropertyStatus.verificado:
        return 'Verificado';
      case PropertyStatus.enRevision:
        return 'En revision';
      case PropertyStatus.alerta:
        return 'Alerta';
    }
  }

  /// Color principal del semaforo.
  Color get color {
    switch (this) {
      case PropertyStatus.verificado:
        return AppColors.statusVerified;
      case PropertyStatus.enRevision:
        return AppColors.statusReview;
      case PropertyStatus.alerta:
        return AppColors.statusAlert;
    }
  }

  /// Color de fondo suave para la etiqueta.
  Color get backgroundColor {
    switch (this) {
      case PropertyStatus.verificado:
        return AppColors.statusVerifiedBg;
      case PropertyStatus.enRevision:
        return AppColors.statusReviewBg;
      case PropertyStatus.alerta:
        return AppColors.statusAlertBg;
    }
  }

  IconData get icon {
    switch (this) {
      case PropertyStatus.verificado:
        return Icons.verified;
      case PropertyStatus.enRevision:
        return Icons.hourglass_top;
      case PropertyStatus.alerta:
        return Icons.warning_amber_rounded;
    }
  }
}
