import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:solana/solana.dart';
import 'package:solana/base58.dart';
import 'package:solana_mobile_client/solana_mobile_client.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tok',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF9945FF),
          secondary: Color(0xFF14F195),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Cliente RPC de Solana (devnet para desarrollo)
  late SolanaClient solanaClient;

  // Estado de la wallet
  String? authToken;
  Uint8List? publicKey;
  double balance = 0.0;
  bool loading = false;
  String status = '';

  @override
  void initState() {
    super.initState();
    solanaClient = SolanaClient(
      rpcUrl: Uri.parse('https://api.devnet.solana.com'),
      websocketUrl: Uri.parse('wss://api.devnet.solana.com'),
    );
  }

  bool get isConnected => authToken != null && publicKey != null;

  String get walletAddress {
    if (publicKey == null) return '';
    final address = base58encode(publicKey!.toList());
    return '${address.substring(0, 8)}...${address.substring(address.length - 8)}';
  }

  // Conectar wallet via MWA
  Future<void> connectWallet() async {
    setState(() {
      loading = true;
      status = 'Abriendo wallet...';
    });

    try {
      final session = await LocalAssociationScenario.create();
      await session.startActivityForResult(null);
      final client = await session.start();

      final result = await client.authorize(
        identityUri: Uri.parse('https://localhost'),
        iconUri: Uri.parse('favicon.ico'),
        identityName: 'Tok',
        cluster: 'devnet',
      );

      if (result != null) {
        setState(() {
          authToken = result.authToken;
          publicKey = result.publicKey;
          status = 'Wallet conectada';
        });
        await fetchBalance();
      }

      await session.close();
    } catch (e) {
      setState(() => status = 'Error: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  // Desconectar wallet
  Future<void> disconnectWallet() async {
    if (authToken == null) return;
    setState(() => loading = true);

    try {
      final session = await LocalAssociationScenario.create();
      await session.startActivityForResult(null);
      final client = await session.start();
      await client.deauthorize(authToken: authToken!);
      await session.close();
    } catch (e) {
      // ignorar error al desconectar
    } finally {
      setState(() {
        authToken = null;
        publicKey = null;
        balance = 0.0;
        loading = false;
        status = 'Wallet desconectada';
      });
    }
  }

  // Obtener balance
  Future<void> fetchBalance() async {
    if (publicKey == null) return;
    setState(() => status = 'Obteniendo balance...');

    try {
      final address = base58encode(publicKey!.toList());
      final response = await solanaClient.rpcClient.getBalance(address);
      setState(() {
        balance = response.value / 1000000000; // lamports a SOL
        status = '';
      });
    } catch (e) {
      setState(() => status = 'Error al obtener balance: $e');
    }
  }

  // Solicitar airdrop (solo devnet)
  Future<void> requestAirdrop() async {
    if (publicKey == null) return;
    setState(() {
      loading = true;
      status = 'Solicitando airdrop...';
    });

    try {
      await solanaClient.requestAirdrop(
        address: Ed25519HDPublicKey(publicKey!.toList()),
        lamports: 1000000000, // 1 SOL
      );
      // Esperar confirmación
      await Future.delayed(const Duration(seconds: 3));
      await fetchBalance();
      setState(() => status = 'Airdrop recibido!');
    } catch (e) {
      setState(() => status = 'Error airdrop: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF9945FF),
        title: const Text('Tok', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icono
              Icon(
                isConnected ? Icons.account_balance_wallet : Icons.wallet_outlined,
                size: 90,
                color: const Color(0xFF14F195),
              ),
              const SizedBox(height: 32),

              if (isConnected) ...[
                // Dirección
                Text(
                  walletAddress,
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                ),
                const SizedBox(height: 16),

                // Balance
                Text(
                  '${balance.toStringAsFixed(4)} SOL',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                // Status
                if (status.isNotEmpty)
                  Text(status, style: const TextStyle(color: Colors.white38, fontSize: 13)),

                const SizedBox(height: 40),

                // Botón refresh balance
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: loading ? null : fetchBalance,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Actualizar Balance'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E1E3A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Botón airdrop
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: loading ? null : requestAirdrop,
                    icon: const Icon(Icons.download),
                    label: const Text('Airdrop 1 SOL (devnet)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF14F195),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Botón desconectar
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: loading ? null : disconnectWallet,
                    icon: const Icon(Icons.logout, color: Colors.redAccent),
                    label: const Text('Desconectar', style: TextStyle(color: Colors.redAccent)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ] else ...[
                // No conectado
                const Text(
                  'Conecta tu wallet\npara continuar',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 20),
                ),
                const SizedBox(height: 8),
                if (status.isNotEmpty)
                  Text(status, style: const TextStyle(color: Colors.white38, fontSize: 13)),
                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: loading ? null : connectWallet,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9945FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Conectar Wallet', style: TextStyle(fontSize: 17)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}