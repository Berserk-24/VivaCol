import 'package:flutter/material.dart';

/// Paleta de colores centralizada de VivaCol.
/// Incluye colores de marca y los colores del sistema de semaforo
/// que indican la fiabilidad de cada publicacion.
class AppColors {
  AppColors._();

  // Colores de marca
  static const Color primaryBlue = Color(0xFF378ADD);
  static const Color accentGreen = Color(0xFF5DCAA5);

  // Neutros
  static const Color white = Color(0xFFFFFFFF);
  static const Color offWhite = Color(0xFFF5F5F3);
  static const Color darkGray = Color(0xFF2B2B2B);
  static const Color mediumGray = Color(0xFF7A7A7A);
  static const Color lightGray = Color(0xFFE0E0E0);

  // Colores del semaforo de estado
  static const Color statusVerified = Color(0xFF2FBF71); // verde: verificado
  static const Color statusReview = Color(0xFFE0A82E); // mostaza: en revision
  static const Color statusAlert = Color(0xFFE8552D); // naranja/rojo: alerta

  // Fondos suaves para las etiquetas de estado
  static const Color statusVerifiedBg = Color(0xFFE3F6EC);
  static const Color statusReviewBg = Color(0xFFFBF1D9);
  static const Color statusAlertBg = Color(0xFFFCE5DD);
}
