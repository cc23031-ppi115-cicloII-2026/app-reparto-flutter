import 'package:flutter/material.dart';
import '../../control/auth_control.dart';
import '../../entity/sesion_usuario.dart';
import '../../theme/swoosh_colors.dart';

class LoginScreen extends StatefulWidget {
  final void Function(SesionUsuario sesion) onLoginExitoso;

  const LoginScreen({
    super.key,
    required this.onLoginExitoso,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthControl _authControl = AuthControl();
  final TextEditingController _usuarioCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  bool _cargando = false;
  bool _ocultarPassword = true;
  String? _mensajeError;

  @override
  void dispose() {
    _usuarioCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviarLogin() async {
    setState(() {
      _cargando = true;
      _mensajeError = null;
    });

    final resultado = await _authControl.iniciarSesion(
      usuario: _usuarioCtrl.text,
      password: _passwordCtrl.text,
    );

    if (!mounted) return;
    setState(() => _cargando = false);

    if (resultado.exitoso) {
      if (resultado.modoOffline) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sesión iniciada en modo offline (caché local)'),
          ),
        );
      }
      widget.onLoginExitoso(resultado.sesion!);
    } else {
      setState(() => _mensajeError = resultado.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              color: SwooshColors.blanco,
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: SwooshColors.azulClaro),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.bolt_rounded,
                      size: 56,
                      color: SwooshColors.azulPrimario,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'SWOOSH',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: SwooshColors.azulMarino,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Inicia sesión como Negocio o Repartidor',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: SwooshColors.textoSecundario,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _usuarioCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Usuario',
                        hintText: 'Ej. negocio1 o rep1',
                        prefixIcon: Icon(
                          Icons.person_outline,
                          color: SwooshColors.azulPrimario,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _passwordCtrl,
                      obscureText: _ocultarPassword,
                      onSubmitted: (_) => _cargando ? null : _enviarLogin(),
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: SwooshColors.azulPrimario,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _ocultarPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(
                            () => _ocultarPassword = !_ocultarPassword,
                          ),
                        ),
                      ),
                    ),
                    if (_mensajeError != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          _mensajeError!,
                          style: TextStyle(
                            color: Colors.red.shade800,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _cargando ? null : _enviarLogin,
                      icon: _cargando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.login),
                      label: Text(_cargando ? 'Verificando...' : 'Ingresar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}