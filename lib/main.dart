import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'api_client.dart';

void main() => runApp(const InvestigationsMobileApp());

class InvestigationsMobileApp extends StatelessWidget {
  const InvestigationsMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Investigations Mobile',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const ConnectScreen(),
    );
  }
}

// ------------------------------------------------------------------
// Connect Screen – QR scan + manual IP with connection test
// ------------------------------------------------------------------
class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final MobileScannerController controller = MobileScannerController();
  bool _isScanning = true;
  bool _isConnecting = false;

  void _onDetect(BarcodeCapture capture) {
    if (!_isScanning || _isConnecting) return;
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        final ip = barcode.rawValue!;
        // Validate IP format
        if (RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(ip)) {
          _handleIp(ip);
          return;
        }
      }
    }
  }

  Future<void> _handleIp(String ip) async {
    setState(() {
      _isScanning = false;
      _isConnecting = true;
    });
    controller.stop();

    // Test connection
    final bool reachable = await _testServer(ip);
    if (!mounted) return;
    setState(() => _isConnecting = false);

    if (reachable) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => CaseListScreen(serverIp: ip)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('❌ Cannot reach server. Check the IP and try again.'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () {
              setState(() {
                _isScanning = true;
                _isConnecting = false;
              });
              controller.start();
            },
          ),
        ),
      );
      // Reset scanner
      setState(() {
        _isScanning = true;
        _isConnecting = false;
      });
      controller.start();
    }
  }

  Future<bool> _testServer(String ip) async {
    try {
      final url = Uri.parse('http://$ip:8080/cases');
      final response = await http.get(url).timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR to connect')),
      body: Column(
        children: [
          Expanded(
            child: _isConnecting
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 20),
                        Text('Connecting to server...'),
                      ],
                    ),
                  )
                : MobileScanner(
                    controller: controller,
                    onDetect: _onDetect,
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: () {
                    controller.start();
                    setState(() {
                      _isScanning = true;
                      _isConnecting = false;
                    });
                  },
                  child: const Text('Restart scanner'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Or enter IP manually',
                    border: OutlineInputBorder(),
                  ),
                  onFieldSubmitted: (ip) {
                    if (RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(ip)) {
                      _handleIp(ip);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Invalid IP format')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------
// Case List Screen
// ------------------------------------------------------------------
class CaseListScreen extends StatefulWidget {
  final String serverIp;
  const CaseListScreen({super.key, required this.serverIp});

  @override
  State<CaseListScreen> createState() => _CaseListScreenState();
}

class _CaseListScreenState extends State<CaseListScreen> {
  late ApiClient _api;
  List<dynamic> _cases = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = ApiClient(serverIp: widget.serverIp);
    _loadCases();
  }

  Future<void> _loadCases() async {
    try {
      final cases = await _api.getCases();
      setState(() {
        _cases = cases;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to connect: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Case List')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _error = null;
                            _loadCases();
                          });
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _cases.isEmpty
                  ? const Center(child: Text('No cases found.'))
                  : ListView.builder(
                      itemCount: _cases.length,
                      itemBuilder: (context, index) {
                        final caseData = _cases[index];
                        return Card(
                          child: ListTile(
                            leading: Text(caseData['routeType'] == 'Referral' ? '📩' : '🕵️'),
                            title: Text(caseData['complaintDescription'] ?? 'Untitled'),
                            subtitle: Text('Status: ${caseData['status']}'),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CaseDetailScreen(
                                    serverIp: widget.serverIp,
                                    caseId: caseData['id'],
                                    caseData: caseData,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
    );
  }
}

// ------------------------------------------------------------------
// Case Detail Screen
// ------------------------------------------------------------------
class CaseDetailScreen extends StatefulWidget {
  final String serverIp;
  final int caseId;
  final Map<String, dynamic> caseData;

  const CaseDetailScreen({
    super.key,
    required this.serverIp,
    required this.caseId,
    required this.caseData,
  });

  @override
  State<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends State<CaseDetailScreen> {
  late ApiClient _api;
  Map<String, dynamic> _case = {};

  @override
  void initState() {
    super.initState();
    _api = ApiClient(serverIp: widget.serverIp);
    _loadCaseDetails();
  }

  Future<void> _loadCaseDetails() async {
    try {
      final details = await _api.getCase(widget.caseId);
      setState(() {
        _case = details;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Case Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Case #${widget.caseId}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('Description: ${widget.caseData['complaintDescription']}'),
            const SizedBox(height: 12),
            Text('Status: ${widget.caseData['status']}'),
            // You can add more fields here – e.g., files, notes, etc.
          ],
        ),
      ),
    );
  }
}