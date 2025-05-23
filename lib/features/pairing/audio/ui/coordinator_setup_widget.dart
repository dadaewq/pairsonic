part of 'grouppairing_audio_widgets.dart';

class GPCoordinatorSettings {
  final int selectedParticipantCount;
  final int selectedCommScheme;

  const GPCoordinatorSettings(
      {required this.selectedParticipantCount,
        required this.selectedCommScheme});
}

/// Widget that is used in the group pairing process to allow the coordinator
/// to configure the group pairing parameters.
///
/// {@category Widgets}
class GPCoordinatorSetupWidget extends StatefulWidget {
  final GroupPairingUIState _uiState;
  final Sink<double> _pairingProgressSink;
  final Sink<String> _appBarTitleSink;

  const GPCoordinatorSetupWidget({
    super.key,
    required uiState,
    required progressSink,
    required appBarTitleSink}) :
        _uiState = uiState,
        _pairingProgressSink = progressSink,
        _appBarTitleSink = appBarTitleSink;

  @override
  State<GPCoordinatorSetupWidget> createState() =>
      _GPCoordinatorSetupWidgetState(_pairingProgressSink, _appBarTitleSink);
}

enum GPCoordinatorSetupStep { participantCountSelection, ready }

class _GPCoordinatorSetupWidgetState extends State<GPCoordinatorSetupWidget> {
  static const commSchemeDecentralized = 1;

  static const int minNumParticipants = 2;

  late int _selectedCommScheme;
  var _currentStep = GPCoordinatorSetupStep.participantCountSelection;

  final Sink<double> _pairingProgressSink;
  final Sink<String> _appBarTitleSink;

  int numParticipants = 0;

  final TextEditingController _customNumberController = TextEditingController(text: "");

  _GPCoordinatorSetupWidgetState(this._pairingProgressSink, this._appBarTitleSink);

  @override
  void initState() {
    super.initState();
    if (widget._uiState.coordinatorSettings != null) {
      _selectedCommScheme =
          widget._uiState.coordinatorSettings!.selectedCommScheme;
    } else {
      _selectedCommScheme = kDebugMode ? -1 : 0;
    }

    _setCommScheme(commSchemeDecentralized);
    // Reset the UI state to ensure that everything (audio channel,
    // communication channel, etc.) is in a clean state.
    widget._uiState.reset();
    _pairingProgressSink.add(0.1);
  }

  @override
  Widget build(BuildContext context) {
    if (_currentStep == GPCoordinatorSetupStep.participantCountSelection) {
      _appBarTitleSink.add(S.of(context).groupPairingSetupGroupSize);
    }
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: Column(
          children: _currentStep == GPCoordinatorSetupStep.participantCountSelection ? buildParticipantSelectionColumn(context) : buildReadyColumn(context),
        ),
      ),
    );
  }

  List<Widget> buildParticipantSelectionColumn(BuildContext context) {
    return [
      Expanded(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: buildParticipantCountSelectionColumn(context),
          ),
        ),
      ),
      const SizedBox(height: 10),
      buildButtonRow(context),
    ];
  }

  List<Widget> buildParticipantCountSelectionColumn(BuildContext context) {
    return [
      const SizedBox(height: 10),
      HintTextCard(
          S.of(context).groupPairingSetupParticipantCountDescription,
          icon: Icons.groups
      ),
      const SizedBox(height: 10),
      GridView.count(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: List.generate(6, (i) {
          final num = i + minNumParticipants;
          return TappableNumberCard(num, onTap: () {
            _appBarTitleSink.add("Ready");
            _pairingProgressSink.add(0.15);
            setState(() {
              this.numParticipants = num;
              _currentStep = GPCoordinatorSetupStep.ready;
            });
          }
          );
        }),
      ),
      const SizedBox(height: 15),
      Padding(
        padding: const EdgeInsets.only(left: 8.0, right: 8.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              "Or enter a custom size:",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(width: 20),
            Expanded(
              child: TextField(
                maxLines: 1,
                controller: _customNumberController,
                keyboardType: TextInputType.number,
                style: Theme.of(context).textTheme.titleLarge,
                decoration: const InputDecoration(hintText: "0"),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly
                ],
                onChanged: (value) {
                  setState(() {
                    final num = int.tryParse(value);
                    numParticipants = num ?? 0;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> buildReadyColumn(BuildContext context) {
    return [
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Icon(Icons.arrow_upward_rounded,
            size: MediaQuery.of(context).size.height * 0.25),
      ),
      const Spacer(),
      Container(
          padding: const EdgeInsets.fromLTRB(60, 0, 60, 5),
          child: GuiConstants.svgAssetExchange(
              context,
              height: MediaQuery.of(context).size.height * 0.25
          )
      ),
      const Spacer(),
      HintTextCard(S.of(context).groupPairingSetupHintReady),
      const SizedBox(height: 15),
      buildButtonRow(context)
    ];
  }

  Widget buildButtonRow(BuildContext context) {
    return ButtonRow(
      primaryText: _currentStep == GPCoordinatorSetupStep.ready
          ? S.of(context).groupPairingSetupGo
          : S.of(context).groupPairingSetupConfirm,
      primaryIcon: Icons.arrow_forward_rounded,
      primaryAction: numParticipants < 2 ? null : (context) async {
        switch (_currentStep) {
          case GPCoordinatorSetupStep.participantCountSelection:
            _pairingProgressSink.add(0.15);
            _appBarTitleSink.add("Ready");
            setState(() {
              _currentStep = GPCoordinatorSetupStep.ready;
            });
          case GPCoordinatorSetupStep.ready:
            _appBarTitleSink.add("Waiting...");
            bool res = await _initGroupPairingProtocol();
            if (res && context.mounted) {
              Navigator.of(context)
                  .pushNamed(GroupPairingAudioRoutes.running);
            }
        }
      },
      secondaryText: S.of(context).groupPairingSetupBack,
      secondaryIcon: Icons.arrow_back_rounded,
      secondaryAction: (context) {
        switch (_currentStep) {
          case GPCoordinatorSetupStep.participantCountSelection:
            _pairingProgressSink.add(0.05);
            _appBarTitleSink.add("Ready");
            Navigator.of(context).pop();
          case GPCoordinatorSetupStep.ready:
            _pairingProgressSink.add(0.1);
            _appBarTitleSink.add(S.of(context).groupPairingSetupGroupSize);
            setState(() {
              numParticipants = 0;
              _currentStep =
                  GPCoordinatorSetupStep.participantCountSelection;
            });
        }
      },
    );
  }

  /// Prompts the user to enable WiFi
  Future<void> _promptWifi() async {
    await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(S.of(context).wifiEnableDialogTitle),
          content: Text(S.of(context).wifiEnableDialogDescription),
          actions: [
            ElevatedButton(
                onPressed: Navigator.of(context).pop,
                child: Text(S.of(context).dialogButtonOK))
          ],
        ));
  }

  /// Inits the group pairing protocol before sending the user to the next screen.
  Future<bool> _initGroupPairingProtocol() async {
    switch (_selectedCommScheme) {
      case commSchemeDecentralized:
      // Creating a [GPWifiP2pCommunication] might fail when Wi-Fi is disabled.
        try {
          widget._uiState.comm = await GPWifiP2pCommunication.create(numParticipants);
        } on WifiP2pException catch (_) {
          await _promptWifi();
          return false;
        }
        break;
      default:
        throw Exception("Unknown communication scheme $_selectedCommScheme");
    }
    widget._uiState.coordinatorSettings = GPCoordinatorSettings(
        selectedParticipantCount: numParticipants,
        selectedCommScheme: _selectedCommScheme);
    return true;
  }

  void _setCommScheme(int? s) {
    setState(() {
      _selectedCommScheme = s ?? 0;
    });
  }
}
