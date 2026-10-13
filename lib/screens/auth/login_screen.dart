import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';

/// Pantalla de inicio de sesion / registro con Firebase Authentication
/// y seleccion del tipo de usuario.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isRegister = false;
  bool _submitting = false;
  UserRole _selectedRole = UserRole.buscador;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);

    final auth = context.read<AuthProvider>();
    final email = _emailController.text;
    final password = _passwordController.text;

    final error = _isRegister
        ? await auth.register(
            name: _nameController.text,
            email: email,
            password: password,
            role: _selectedRole,
          )
        : await auth.signIn(email, password);

    if (!mounted) return;
    setState(() => _submitting = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.statusAlert),
      );
    }
    // En caso de exito, el router redirige automaticamente a /home.
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
            if (_isRegister) ...[
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre o inmobiliaria',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresa un nombre';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
            ],
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
                if (value == null || value.length < 6) {
                  return 'Minimo 6 caracteres';
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
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : Text(_isRegister ? 'Registrarme' : 'Entrar'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _submitting
                  ? null
                  : () => setState(() => _isRegister = !_isRegister),
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
