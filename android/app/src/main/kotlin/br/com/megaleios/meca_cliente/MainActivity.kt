package br.com.megaleios.meca_cliente

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager: NotificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            
            // Deletar channel antigo se existir (para forçar recriação com novas configurações)
            try {
                notificationManager.deleteNotificationChannel("meca_high_importance")
            } catch (e: Exception) {
                // Channel não existe, continuar
            }
            
            val name = "Notificações MECA (Importante)"
            val descriptionText = "Canal principal para notificações MECA"
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel("meca_high_importance", name, importance).apply {
                description = descriptionText
                enableVibration(true)
                enableLights(true)
                // Configurar som padrão do sistema (Android 8+)
                setSound(android.provider.Settings.System.DEFAULT_NOTIFICATION_URI, null)
                // Permitir quebrar Do Not Disturb (Android 8+)
                setBypassDnd(false)
                // Mostrar badge (Android 8+)
                setShowBadge(true)
            }
            notificationManager.createNotificationChannel(channel)
        }
    }
}
