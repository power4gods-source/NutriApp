import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// Pantalla reutilizable con Términos y Condiciones + Política de Privacidad
class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        title: const Text(
          'Términos y Condiciones',
          style: TextStyle(
            color: Colors.black87,
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
            Text(
              'Última actualización: 8 de febrero de 2026',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
              '1.3. Subida de Información o Propiedad de Terceros',
              'La subida de información, imágenes, textos, recetas o cualquier contenido que sea propiedad intelectual o de terceros es responsabilidad exclusiva del usuario que lo sube. CooKind no se hace responsable de las infracciones de derechos de autor, marcas o propiedad intelectual que puedan derivarse del contenido publicado por los usuarios. El usuario garantiza que dispone de los derechos necesarios sobre todo el contenido que publique y asume toda responsabilidad legal ante reclamaciones de terceros.',
            ),
            _buildTermsSubsection(
              '1.4. Renuncia a Acciones Legales',
              'Mediante la aceptación de estos términos, el usuario renuncia expresamente a interponer cualquier demanda, querella o reclamación civil, penal o administrativa contra CooKind o el Titular de la App por conceptos de:\n• Errores en la información nutricional.\n• Fallos técnicos o pérdida de datos de su historial alimenticio.\n• Comportamiento inapropiado de otros usuarios en el chat.',
            ),
            _buildTermsSection(
              '2. POLÍTICA DE PRIVACIDAD',
              'Esta política regula el tratamiento de datos personales conforme al Reglamento (UE) 2016/679 (RGPD) y la LOPDGDD 3/2018.',
            ),
            _buildTermsSubsection(
              '2.0. Información Básica sobre Protección de Datos',
              'Responsable: CooKind.\n\nFinalidad: Gestionar tu perfil de usuario, permitir la creación de recetas y facilitar la interacción social en la App.\n\nLegitimación: Consentimiento del interesado y ejecución de los Términos de Uso.\n\nDestinatarios: No se cederán datos a terceros, salvo obligación legal. No almacenamos datos bancarios.\n\nDerechos: Tienes derecho a acceder, rectificar y suprimir tus datos, así como otros derechos detallados en el apartado 2.4 (Derechos del Usuario ARCO+).',
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
    );
  }

  static Widget _buildTermsSection(String title, String content) {
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
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[800],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildTermsSubsection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
