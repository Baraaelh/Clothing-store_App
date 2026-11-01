import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/api_config.dart';
import '../cubit/auth_cubit.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _obscure = true;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _submit() => context.read<AuthCubit>().login(_username.text, _password.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: BlocBuilder<AuthCubit, AuthState>(
                builder: (context, state) {
                  final form = state is AuthUnauthenticated ? state : const AuthUnauthenticated();
                  return AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(Icons.checkroom, size: 64, color: theme.colorScheme.primary),
                        const SizedBox(height: 12),
                        Text('متجر الأناقة', textAlign: TextAlign.center, style: theme.textTheme.headlineMedium),
                        const SizedBox(height: 4),
                        Text(
                          'سجّل الدخول للبدء',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 32),
                        if (form.sessionExpired) ...[
                          const _Banner(
                            icon: Icons.lock_clock_outlined,
                            text: 'انتهت الجلسة. سجّل الدخول من جديد، والعمليات غير المرسلة ما زالت محفوظة على الجهاز.',
                          ),
                          const SizedBox(height: 16),
                        ],
                        TextField(
                          controller: _username,
                          enabled: !form.submitting,
                          autofillHints: const [AutofillHints.username],
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => _passwordFocus.requestFocus(),
                          decoration: const InputDecoration(
                            labelText: 'اسم المستخدم',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _password,
                          focusNode: _passwordFocus,
                          enabled: !form.submitting,
                          obscureText: _obscure,
                          autofillHints: const [AutofillHints.password],
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: 'كلمة المرور',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              tooltip: _obscure ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور',
                              icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                        ),
                        if (form.error != null) ...[
                          const SizedBox(height: 12),
                          Text(form.error!, style: TextStyle(color: theme.colorScheme.error)),
                        ],
                        const SizedBox(height: 24),
                        FilledButton(
                          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                          onPressed: form.submitting ? null : _submit,
                          child: form.submitting
                              ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('تسجيل الدخول'),
                        ),
                        if (ApiConfig.isDevMode) ...[
                          const SizedBox(height: 16),
                          const _Banner(
                            icon: Icons.science_outlined,
                            text: 'وضع تجريبي: الـ API غير مضبوط، فأي اسم وكلمة مرور تدخل كمالك على الفرع 1.',
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: scheme.secondaryContainer, borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: scheme.onSecondaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text, style: TextStyle(color: scheme.onSecondaryContainer)),
            ),
          ],
        ),
      ),
    );
  }
}
