import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';
import 'package:dartssh2/dartssh2.dart';

class SshPage extends StatefulWidget {
  const SshPage({super.key});
  @override
  State<SshPage> createState() => _SshPageState();
}

class _SshPageState extends State<SshPage> {
  // 左侧表单
  final _host = TextEditingController(text: '127.0.0.1');
  final _port = TextEditingController(text: '22');
  final _user = TextEditingController(text: 'root');
  final _password = TextEditingController();
  final _privateKeyPem = TextEditingController();
  final _passphrase = TextEditingController();
  bool _useKey = false;
  bool _sidebarExpanded = true;

  // 动画期间屏蔽指针，避免 MouseTracker 再入
  bool _resizing = false;

  // 终端 & SSH
  final Terminal _terminal = Terminal(maxLines: 20000);
  final TerminalController _terminalController = TerminalController();
  final FocusNode _terminalFocus = FocusNode(debugLabel: 'terminal_focus');

  SSHClient? _client;
  SSHSession? _session;
  StreamSubscription<Uint8List>? _stdoutSub;
  StreamSubscription<Uint8List>? _stderrSub;

  bool _connecting = false;
  bool _connected = false;

  @override
  void initState() {
    super.initState();

    // 兼容 xterm 3.x(String) / 4.x(Uint8List) 的输出回调
    (_terminal as dynamic).onOutput = (data) {
      final s = _session;
      if (s == null || data == null) return;
      if (data is Uint8List) {
        s.write(data);
      } else if (data is String) {
        s.write(Uint8List.fromList(utf8.encode(data)));
      } else {
        final str = data.toString();
        if (str.isNotEmpty) {
          s.write(Uint8List.fromList(utf8.encode(str)));
        }
      }
    };

    // 终端尺寸变化 -> 通知远端 PTY
    _terminal.onResize = (w, h, wp, hp) {
      _session?.resizeTerminal(w, h, wp, hp);
    };

    _terminal.write('eDbg SSH Terminal\n');
  }

  @override
  void dispose() {
    _stdoutSub?.cancel();
    _stderrSub?.cancel();
    _session?.close();
    _client?.close();

    _terminalController.dispose();
    _terminalFocus.dispose();

    _host.dispose();
    _port.dispose();
    _user.dispose();
    _password.dispose();
    _privateKeyPem.dispose();
    _passphrase.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (_connecting || _connected) return;
    setState(() => _connecting = true);

    try {
      final host = _host.text.trim();
      final port = int.tryParse(_port.text.trim()) ?? 22;
      final username = _user.text.trim();
      if (host.isEmpty || username.isEmpty) {
        throw Exception('Host 和 Username 不能为空');
      }

      _terminal.write('\r\n[Connecting to $host:$port as $username...]\r\n');

      final socket = await SSHSocket.connect(host, port, timeout: const Duration(seconds: 8));

      // 私钥（可选）
      List<SSHKeyPair>? identities;
      if (_useKey && _privateKeyPem.text.trim().isNotEmpty) {
        final pass = _passphrase.text.isEmpty ? null : _passphrase.text;
        identities = SSHKeyPair.fromPem(_privateKeyPem.text, pass);
      }

      final client = SSHClient(
        socket,
        username: username,
        identities: identities,
        onPasswordRequest: _useKey ? null : () => _password.text,
        onVerifyHostKey: (host, key) => true, // 示例：信任主机指纹；生产环境请替换为严格校验
        onUserauthBanner: (msg) => _terminal.write(msg),
        onAuthenticated: () => _terminal.write('[Authenticated]\r\n'),
      );
      _client = client;

      await client.authenticated;

      // 开交互式 shell（宽高初值，实际由 onResize 持续同步）
      final session = await client.shell(
        pty: SSHPtyConfig(width: 120, height: 30),
      );
      _session = session;

      // 远端 -> 终端（UTF-8 兜底解码）
      _stdoutSub = session.stdout.listen((data) {
        _terminal.write(const Utf8Decoder(allowMalformed: true).convert(data));
      });
      _stderrSub = session.stderr.listen((data) {
        _terminal.write(const Utf8Decoder(allowMalformed: true).convert(data));
      });

      session.done.then((_) {
        _terminal.write('\r\n[Disconnected]\r\n');
        if (mounted) {
          setState(() {
            _connected = false;
            _connecting = false;
          });
        }
      });

      setState(() {
        _connected = true;
        _connecting = false;
      });
      _terminal.write('[Shell started]\r\n');
      // 连接成功后，把焦点交给终端，方便直接输入
      _terminalFocus.requestFocus();
    } catch (e) {
      setState(() => _connecting = false);
      _terminal.write('\r\n[ERROR] $e\r\n');
    }
  }

  void _disconnect() {
    _stdoutSub?.cancel();
    _stderrSub?.cancel();
    _session?.close();
    _client?.close();
    _session = null;
    _client = null;
    setState(() => _connected = false);
    _terminal.write('\r\n[Closed]\r\n');
  }

  Future<void> _pasteClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final t = data?.text;
    if (t != null && t.isNotEmpty) {
      _terminal.paste(t);
    }
  }

  void _toggleSidebar() {
    setState(() {
      _sidebarExpanded = !_sidebarExpanded;
      _resizing = true; // 动画期间屏蔽指针事件
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        // 左侧：可收起连接栏（TextField 现在能正常获得焦点）
        AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: _sidebarExpanded ? 300 : 44,
          decoration: BoxDecoration(
            color: cs.surfaceContainerLowest,
            border: Border(right: BorderSide(color: cs.outlineVariant)),
          ),
          child: _sidebarExpanded ? _buildSidebar(context) : _buildCollapsedBar(),
        ),

        // 右侧：终端
        Expanded(
          child: Scaffold(
            backgroundColor: cs.surface,
            appBar: AppBar(
              elevation: 0,
              scrolledUnderElevation: 0,
              title: Text(_connected ? 'SSH • Connected' : _connecting ? 'SSH • Connecting...' : 'SSH'),
              actions: [
                IconButton(
                  tooltip: '粘贴',
                  onPressed: _pasteClipboard,
                  icon: const Icon(Icons.content_paste_go_outlined),
                ),
                if (!_connected)
                  FilledButton.icon(
                    onPressed: _connecting ? null : _connect,
                    icon: const Icon(Icons.login),
                    label: const Text('连接'),
                  )
                else
                  FilledButton.tonalIcon(
                    onPressed: _disconnect,
                    icon: const Icon(Icons.logout),
                    label: const Text('断开'),
                  ),
                const SizedBox(width: 8),
              ],
            ),
            body: Container(
              color: cs.surface,
              alignment: Alignment.topLeft,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _terminalFocus.requestFocus(), // 点击终端区域再手动获取焦点
                child: TerminalView(
                  _terminal,
                  controller: _terminalController,
                  autofocus: false,            // 关键：不自动抢焦点
                  focusNode: _terminalFocus,   // 用我们自管的 FocusNode
                  backgroundOpacity: 1.0,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCollapsedBar() {
    return Column(
      children: [
        const SizedBox(height: 8),
        IconButton(
          tooltip: '展开',
          onPressed: () => setState(() => _sidebarExpanded = true),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _buildSidebar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(
            children: [
              const Text('连接', style: TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(
                tooltip: '收起',
                onPressed: () => setState(() => _sidebarExpanded = false),
                icon: const Icon(Icons.chevron_left),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _Field(label: 'Host', controller: _host, hint: 'e.g. 192.168.1.10'),
          _Field(label: 'Port', controller: _port, keyboardType: TextInputType.number),
          _Field(label: 'Username', controller: _user),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('使用私钥登录'),
            value: _useKey,
            onChanged: (v) => setState(() => _useKey = v),
          ),
          if (!_useKey) _Field(label: 'Password', controller: _password, obscureText: true),
          if (_useKey) ...[
            _Field(
              label: 'PEM 私钥',
              controller: _privateKeyPem,
              hint: '-----BEGIN ... PRIVATE KEY-----\\n...',
              maxLines: 6,
            ),
            _Field(
              label: 'Passphrase（可选）',
              controller: _passphrase,
              obscureText: true,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                '支持 OpenSSH PEM；必要时用 `ssh-keygen -p -m PEM -f <key>` 转换。',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ),
          ],
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _connected ? null : (_connecting ? null : _connect),
            icon: const Icon(Icons.login),
            label: const Text('连接'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: _connected ? _disconnect : null,
            icon: const Icon(Icons.logout),
            label: const Text('断开'),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool obscureText;
  final int maxLines;
  final TextInputType? keyboardType;

  const _Field({
    required this.label,
    required this.controller,
    this.hint,
    this.obscureText = false,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: cs.surfaceContainerHighest,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}
