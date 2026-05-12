import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mamoney/services/connectivity_provider.dart';

/// Reusable connectivity status indicator widget
/// Shows WiFi icon and connection status text
class ConnectivityIndicator extends StatelessWidget {
  const ConnectivityIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityProvider>(
      builder: (context, connectivityProvider, _) {
        final isConnected = connectivityProvider.isConnected;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isConnected ? Icons.wifi : Icons.wifi_off,
                  color: isConnected
                      ? Colors.green
                      : const Color.fromARGB(255, 211, 47, 47),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isConnected ? 'Connected' : 'No Internet',
                  style: TextStyle(
                    fontSize: 14,
                    color: isConnected
                        ? Colors.green
                        : const Color.fromARGB(255, 211, 47, 47),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
