import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/firebase_sync_service.dart';
import 'dart:convert';

/// Pantalla para gestionar la sincronización con Firebase
class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final FirebaseSyncService _syncService = FirebaseSyncService();
  bool _isSyncing = false;
  String _statusMessage = '';
  Map<String, bool> _uploadResults = {};
  DateTime? _lastSyncTime;

  @override
  void initState() {
    super.initState();
    _loadLastSyncTime();
  }

  Future<void> _loadLastSyncTime() async {
    final time = await _syncService.getLastSyncTime();
    setState(() {
      _lastSyncTime = time;
    });
  }

  Future<void> _uploadToFirebase() async {
    setState(() {
      _isSyncing = true;
      _statusMessage = 'Preparando subida...';
      _uploadResults = {};
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('💡 Para subir archivos JSON, usa Firebase Console manualmente o el script Python'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 5),
        ),
      );
    }
    
    setState(() {
      _isSyncing = false;
      _statusMessage = 'Usa el método manual desde Firebase Console';
    });
    
    // Mostrar instrucciones
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('📤 Subir Archivos a Firebase'),
          content: const SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Para subir los archivos JSON:'),
                SizedBox(height: 12),
                Text('1. Ve a Firebase Console > Storage > Archivos'),
                Text('2. Entra a la carpeta data/'),
                Text('3. Haz clic en "Subir archivo"'),
                Text('4. Selecciona los JSON desde:'),
                Text('   C:\\Users\\mball\\Downloads\\NutriApp\\'),
                SizedBox(height: 12),
                Text('Archivos a subir:'),
                Text('• recipes.json'),
                Text('• foods.json'),
                Text('• users.json'),
                Text('• profiles.json'),
                Text('• Y los demás JSON...'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _downloadFromFirebase() async {
    setState(() {
      _isSyncing = true;
      _statusMessage = 'Descargando datos desde Firebase...';
    });

    try {
      // Paso 1: Descargar desde Firebase
      final cloudData = await _syncService.downloadAllJsonFiles();
      
      if (cloudData.isEmpty) {
        setState(() {
          _statusMessage = 'No se encontraron archivos en Firebase';
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No hay archivos disponibles en Firebase'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      setState(() {
        _statusMessage = 'Guardando ${cloudData.length} archivos localmente...';
      });
      
      // Paso 2: Guardar localmente (y opcionalmente enviar al backend si está disponible)
      final success = await _syncService.syncToBackend(cloudData);
      
      if (success) {
        setState(() {
          _statusMessage = 'Descarga completada: ${cloudData.length} archivos guardados';
        });
        
        await _syncService.saveLastSyncTime();
        await _loadLastSyncTime();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${cloudData.length} archivos descargados y guardados correctamente'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        setState(() {
          _statusMessage = 'Error al guardar datos localmente';
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al guardar los datos descargados'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al descargar datos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  Future<void> _checkForUpdates() async {
    setState(() {
      _isSyncing = true;
      _statusMessage = 'Verificando actualizaciones...';
    });

    try {
      final hasUpdates = await _syncService.hasUpdatesAvailable();
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Actualizaciones Disponibles'),
            content: Text(
              hasUpdates
                  ? 'Hay actualizaciones disponibles en Firebase. ¿Deseas descargarlas?'
                  : 'Tu app está actualizada. No hay nuevas actualizaciones.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              if (hasUpdates)
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _downloadFromFirebase();
                  },
                  child: const Text('Descargar'),
                ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al verificar actualizaciones: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSyncing = false;
        _statusMessage = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sincronización Firebase'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Estado de Sincronización',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_lastSyncTime != null)
                      Text(
                        'Última sincronización: ${_lastSyncTime!.toString().substring(0, 19)}',
                        style: TextStyle(color: Colors.grey[600]),
                      )
                    else
                      const Text(
                        'Nunca sincronizado',
                        style: TextStyle(color: Colors.grey),
                      ),
                    if (_statusMessage.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        _statusMessage,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF4CAF50),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Upload button
            ElevatedButton.icon(
              onPressed: _isSyncing ? null : _uploadToFirebase,
              icon: const Icon(Icons.cloud_upload),
              label: const Text('Subir a Firebase'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            // Download button
            ElevatedButton.icon(
              onPressed: _isSyncing ? null : _downloadFromFirebase,
              icon: const Icon(Icons.cloud_download),
              label: const Text('Descargar desde Firebase'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            // Check updates button
            OutlinedButton.icon(
              onPressed: _isSyncing ? null : _checkForUpdates,
              icon: const Icon(Icons.refresh),
              label: const Text('Verificar Actualizaciones'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            
            if (_isSyncing) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
            ],
            
            // Upload results
            if (_uploadResults.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Resultados de Subida',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ..._uploadResults.entries.map((entry) {
                return Card(
                  child: ListTile(
                    title: Text(entry.key),
                    trailing: Icon(
                      entry.value ? Icons.check_circle : Icons.error,
                      color: entry.value ? Colors.green : Colors.red,
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

