import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/app_user.dart';
import '../../theme/app_colors.dart';

/// Pantalla de inicio de sesion / registro con autenticacion simulada
/// y seleccion del tipo de usuario.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isRegister = false;
  UserRole _selectedRole = UserRole.buscador;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    // Autenticacion simulada: navega directo al home.
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isRegister ? 'Crear cuenta' : 'Iniciar sesion'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 8),
            Text(
              _isRegister ? 'Bienvenido a VivaCol' : 'Hola de nuevo',
              style: textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo electronico',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (value) {
                if (value == null || !value.contains('@')) {
                  return 'Ingresa un correo valido';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Contrasena',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              validator: (value) {
                if (value == null || value.length < 4) {
                  return 'Minimo 4 caracteres';
                }
                return null;
              },
            ),
            if (_isRegister) ...[
              const SizedBox(height: 24),
              Text('Que tipo de usuario eres?', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              RadioGroup<UserRole>(
                groupValue: _selectedRole,
                onChanged: (value) =>
                    setState(() => _selectedRole = value ?? _selectedRole),
                child: Column(
                  children: UserRole.values
                      .map(
                        (role) => RadioListTile<UserRole>(
                          value: role,
                          title: Text(role.label),
                          activeColor: AppColors.primaryBlue,
                          contentPadding: EdgeInsets.zero,
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submit,
              child: Text(_isRegister ? 'Registrarme' : 'Entrar'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() => _isRegister = !_isRegister),
              child: Text(
                _isRegister
                    ? 'Ya tengo cuenta, iniciar sesion'
                    : 'No tengo cuenta, registrarme',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
