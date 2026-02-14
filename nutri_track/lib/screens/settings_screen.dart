import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../services/auth_service.dart';
import '../widgets/pronto_badge.dart';
import 'login_screen.dart';
import 'change_password_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        title: Text(
          'Ajustes',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        children: [
          // Account Section
          _buildSectionHeader('Cuenta'),
          _buildSettingsTile(
            context,
            icon: Icons.lock,
            title: 'Contraseña',
            subtitle: 'Cambiar contraseña',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
              );
            },
            showPronto: false,
          ),
          
          const Divider(),
          
          // Soporte / Donaciones
          _buildSectionHeader('Soporte'),
          _buildSettingsTile(
            context,
            icon: Icons.volunteer_activism,
            title: 'Donar a la app',
            subtitle: 'Apoyar el desarrollo de CooKind',
            onTap: () => _showProntoSnack(context),
            showPronto: true,
          ),
          
          const Divider(),
          
          // App Section
          _buildSectionHeader('Aplicación'),
          _buildSettingsTile(
            context,
            icon: Icons.info,
            title: 'Acerca de',
            subtitle: 'Versión 1.0.0',
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('CooKind'),
                  content: const Text('CooKind - Aplicación de recetas y nutrición\nVersión 1.0.0'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cerrar'),
                    ),
                  ],
                ),
              );
            },
          ),
          _buildSettingsTile(
            context,
            icon: Icons.info_outline,
            title: 'Más info',
            subtitle: 'Preguntas frecuentes y sugerencias',
            onTap: () => _showMoreInfo(context),
          ),
          _buildSettingsTile(
            context,
            icon: Icons.shield,
            title: 'Términos y condiciones',
            subtitle: 'Legales y uso de la app',
            onTap: () => _showTermsAndConditions(context),
            showPronto: false,
          ),
          _buildSettingsTile(
            context,
            icon: Icons.share,
            title: 'Invitar amigos',
            subtitle: 'Comparte CooKind',
            onTap: () => _showProntoSnack(context),
            showPronto: true,
          ),
          
          const Divider(),
          
          // Danger Zone
          _buildSettingsTile(
            context,
            icon: Icons.delete_forever,
            title: 'Eliminar cuenta',
            subtitle: 'Eliminar permanentemente tu cuenta',
            textColor: AppTheme.vividRed,
            onTap: () => _showDeleteAccountDialog(context, authService),
            showPronto: false,
          ),
          
          const SizedBox(height: 24),
          
          // Logout button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton.icon(
              onPressed: () async {
                await authService.logout();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar sesión'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.black,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? textColor,
    bool showPronto = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: textColor ?? Colors.grey.shade600),
      title: Text(
        title,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showPronto) const ProntoBadge(),
          if (showPronto) const SizedBox(width: 8),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: onTap,
    );
  }

  void _showProntoSnack(BuildContext context, {String msg = 'Pronto...'}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.orange.shade700,
      ),
    );
  }

  void _showMoreInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.primary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.white54,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Más información',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              _buildFeatureBlockIcon(
                context,
                Icons.info_outline,
                '¿Qué es CooKind?',
                'Cookind es el asistente definitivo que transforma tu cocina en un espacio de creatividad e inteligencia nutricional. Con un catálogo infinito de recetas y una IA avanzada, hacemos que conviertas cualquier ingrediente olvidado en un banquete digno de restaurante. Olvídate de las conjeturas: cada bocado se traduce en un seguimiento preciso de tus macronutrientes para que alcances tus metas físicas sin sacrificar el sabor. Podrás construir tu propia biblioteca culinaria digital, diciendo adiós para siempre al caos de las capturas de pantalla perdidas. Además, la experiencia se vuelve social al permitirte influir en tu comunidad y descubrir las recomendaciones favoritas de tu círculo cercano. Es la herramienta perfecta para quienes buscan variedad, control total sobre sus objetivos y una pizca de inspiración diaria. Todo lo que necesitas para dominar tu alimentación está a un solo toque de distancia. Cocina con propósito, come con placer y comparte tu éxito con el mundo.',
              ),
              _buildMoreInfoDivider(),
              _buildFeatureBlockIcon(
                context,
                Icons.restaurant_menu,
                'De ingredientes a banquete',
                '"Vacía tu nevera sin tirar nada." Solo dinos qué tienes muerto de risa en el cajón de las verduras o la nevera, y nuestra IA cocinará por ti. Convierte tres ingredientes olvidados en una cena digna de restaurante en segundos. Encuéntralo en Inicio > Buscador de recetas o en la pestaña Recetas.',
              ),
              _buildMoreInfoDivider(),
              _buildFeatureBlockIcon(
                context,
                Icons.pie_chart_outline,
                'Tu cuerpo, bajo control',
                '"Come con propósito, no con dudas." Olvídate de las conjeturas; obtén un desglose preciso de proteínas, grasas y carbohidratos en cada bocado. Registra lo que comes para alcanzar tus metas físicas mientras disfrutas de la comida, sabiendo exactamente qué hay en tu plato. Ve a Seguimiento > Agregar consumo. Busca o escanea alimentos y registra tus comidas para ver el desglose al instante.',
              ),
              _buildMoreInfoDivider(),
              _buildFeatureBlockIcon(
                context,
                Icons.menu_book,
                'Tu recetario personal',
                '"Crea la biblioteca culinaria de tus sueños." Despídete de los pantallazos perdidos en la galería de fotos. Guarda, organiza y revive esos platos que te enamoraron con un solo toque, listos para cuando el hambre apriete.',
              ),
              _buildMoreInfoDivider(),
              _buildFeatureBlockIcon(
                context,
                Icons.group,
                'Cocina en comunidad',
                '"Presume de plato y contagia el sabor." No guardes el secreto de esa salsa increíble solo para ti. Envía tus mejores descubrimientos a tus amigos o familia con un clic y disfruta con tu grupo.',
              ),
              const SizedBox(height: 24),
              const Text(
                '¿Necesitas ayuda o tienes sugerencias?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Escríbenos y te responderemos lo antes posible.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextField(
                maxLines: 4,
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Escribe tu consulta, sugerencia o lo que necesites...',
                  hintStyle: const TextStyle(color: Colors.black54),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Gracias. Recibiremos tu mensaje pronto.'),
                        backgroundColor: AppTheme.primary,
                      ),
                    );
                  },
                  icon: const Icon(Icons.send),
                  label: const Text('Enviar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _showTermsAndConditions(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.surface,
            elevation: 0,
            title: Text(
              'Términos y Condiciones',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TÉRMINOS Y CONDICIONES DE USO',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Última actualización: 8 de febrero de 2026',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 20),
                _buildTermsSection(
                  'Cláusula de Exención de Responsabilidad Total',
                  'El Usuario reconoce y acepta que el uso de la App se realiza bajo su propia cuenta y riesgo. CooKind no garantiza la idoneidad, seguridad o exactitud de las recetas, consejos nutricionales o interacciones entre usuarios.',
                ),
                _buildTermsSubsection(
                  '1.1. Inexistencia de Relación Contractual Médica',
                  'La App no es una herramienta médica ni de diagnóstico. El usuario es el único responsable de consultar con un profesional antes de realizar cambios en su dieta. Cualquier daño físico, intoxicación, reacción alérgica o patología derivada de seguir recetas de la App es responsabilidad exclusiva del usuario y del creador de dicha receta, quedando el Titular de la App exento de cualquier indemnización.',
                ),
                _buildTermsSubsection(
                  '1.2. Responsabilidad de Contenidos (Cláusula de Indemnidad)',
                  'El usuario es el único propietario y responsable de los datos, fotos y comentarios que publique. Al usar la App, el usuario se obliga a mantener indemne al Titular de la App ante cualquier reclamación de terceros (incluyendo infracciones de derechos de autor, honor o intimidad).\n\nCooKind no supervisa los contenidos antes de su publicación.\n\nEl usuario acepta que, ante una denuncia judicial, CooKind colaborará con las autoridades facilitando los datos de registro (email e IP) del infractor.',
                ),
                _buildTermsSubsection(
                  '1.3. Renuncia a Acciones Legales',
                  'Mediante la aceptación de estos términos, el usuario renuncia expresamente a interponer cualquier demanda, querella o reclamación civil, penal o administrativa contra CooKind o el Titular de la App por conceptos de:\n• Errores en la información nutricional.\n• Fallos técnicos o pérdida de datos de su historial alimenticio.\n• Comportamiento inapropiado de otros usuarios en el chat.',
                ),
                _buildTermsSection(
                  '2. POLÍTICA DE PRIVACIDAD',
                  'Esta política regula el tratamiento de datos personales conforme al Reglamento (UE) 2016/679 (RGPD) y la LOPDGDD 3/2018.',
                ),
                _buildTermsSubsection(
                  '2.1. Responsable del Tratamiento',
                  'Titular: CooKind\nContacto: power4gods@gmail.com',
                ),
                _buildTermsSubsection(
                  '2.2. Datos Recogidos y Finalidad',
                  'Datos Obligatorios (Email): Gestionar el alta, acceso y recuperación de cuenta. Base legal: Ejecución del contrato.\n\nDatos Voluntarios (Nombre, apellidos, teléfono, dirección, fotos): Facilitar la interacción social y personalización del perfil. Estos datos solo se tratan porque el usuario decide introducirlos y publicarlos.\n\nDatos de Alimentación: Datos introducidos por el usuario para su propio control. Aviso: El usuario es el responsable de no introducir datos de salud sensibles si no desea que sean tratados bajo la seguridad estándar de la App.',
                ),
                _buildTermsSubsection(
                  '2.3. Conservación y Cesión',
                  'Plazo: Los datos se conservarán mientras se mantenga la relación contractual o hasta que el usuario ejerza su derecho de supresión.\n\nCesiones: No se venden datos a terceros. No obstante, por imperativo legal, los datos podrían ser cedidos a Fuerzas y Cuerpos de Seguridad del Estado o Tribunales en caso de investigación.\n\nDatos Bancarios: Se hace constar que la App no recoge, ni almacena ni trata ningún dato bancario ni de tarjetas de crédito.',
                ),
                _buildTermsSubsection(
                  '2.4. Derechos del Usuario (ARCO+)',
                  'El usuario puede ejercer sus derechos de acceso, rectificación, supresión, limitación, oposición y portabilidad enviando un correo a power4gods@gmail.com adjuntando copia de su DNI o documento equivalente.',
                ),
                _buildTermsSubsection(
                  '2.5. Medidas de Seguridad',
                  'El Titular implementa medidas técnicas estándar para evitar el robo de datos, pero el usuario acepta que la seguridad en internet no es inexpugnable. El usuario es responsable de mantener una contraseña robusta.',
                ),
                _buildTermsSection(
                  '3. CLÁUSULA DE JURISDICCIÓN',
                  'Cualquier controversia que surja de la interpretación o ejecución de este contrato se someterá a la legislación española. Las partes renuncian a cualquier otro fuero y se someten a los Juzgados y Tribunales de Valencia, España.',
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTermsSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsSubsection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureBlockIcon(BuildContext context, IconData icon, String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white70, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          description,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white70,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildMoreInfoDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Divider(color: Colors.white24, thickness: 1, height: 1),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, AuthService authService) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Eliminar cuenta'),
            content: const Text(
              '¿Estás seguro de que quieres eliminar tu cuenta?\n\n'
              'Se eliminarán permanentemente todos tus datos: email, contraseña, perfil, '
              'recetas favoritas, historial de consumo, ingredientes, lista de la compra, '
              'recetas privadas y demás información asociada.\n\n'
              'Esta acción no se puede deshacer.',
            ),
            actions: [
              TextButton(
                onPressed: _isDeleting ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: _isDeleting ? null : () async {
                  setDialogState(() => _isDeleting = true);
                  final result = await authService.deleteAccount();
                  if (!context.mounted) return;
                  Navigator.pop(dialogContext);
                  if (result['success'] == true) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Cuenta eliminada correctamente'),
                          backgroundColor: AppTheme.primary,
                        ),
                      );
                      final navigator = Navigator.of(context);
                      if (navigator.mounted) {
                        navigator.pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (route) => false,
                        );
                      }
                    }
                  } else {
                    if (context.mounted) {
                      setState(() => _isDeleting = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(result['error'] ?? 'Error al eliminar la cuenta'),
                          backgroundColor: AppTheme.vividRed,
                        ),
                      );
                    }
                  }
                },
                style: TextButton.styleFrom(foregroundColor: AppTheme.vividRed),
                child: _isDeleting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Sí, seguro'),
              ),
            ],
          );
        },
      ),
    );
  }
}







