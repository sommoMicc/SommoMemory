import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'game.dart';
import 'game_feedback.dart';
import 'online.dart';
import 'palette.dart';
import 'l10n/app_strings.dart';
import 'decks.dart';
import 'economy.dart';
import 'arenas.dart';
import 'invite_links.dart';
import 'network_reconnect.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ui/collection_shop.dart';
import 'ui/arena_picker.dart';
import 'ui/profile_panel.dart';
import 'ui/profile_appearance.dart';
import 'ui/deck_art.dart';
import 'ui/game_world.dart';
import 'ui/store_links.dart';
import 'bluetooth/bluetooth_controller.dart';
import 'voice_chat.dart';

const _systemFontFallback = ['Apple Color Emoji', 'Noto Color Emoji'];
const _fallbackTextStyle = TextStyle(fontFamilyFallback: _systemFontFallback);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final invites = InviteLinks();
  unawaited(invites.start());
  await registerDeckLicenses();
  final prefs = await SharedPreferences.getInstance();
  final economy = EconomyController(prefs: prefs);
  await economy.localReady;
  unawaited(economy.initialize());
  runApp(MyMemory(prefs: prefs, economy: economy, invites: invites));
}

class MyMemory extends StatefulWidget {
  const MyMemory({super.key, required this.prefs, this.economy, this.invites});
  final SharedPreferences prefs;
  final EconomyController? economy;
  final InviteLinks? invites;
  @override
  State<MyMemory> createState() => _MyMemoryState();
}

class _MyMemoryState extends State<MyMemory> {
  late String language;

  @override
  void initState() {
    super.initState();
    final saved = widget.prefs.getString('ui.language');
    language = const {'it', 'en'}.contains(saved) ? saved! : 'auto';
  }

  void setLanguage(String value) {
    if (!const {'auto', 'it', 'en'}.contains(value)) return;
    setState(() => language = value);
    unawaited(widget.prefs.setString('ui.language', value));
  }

  @override
  Widget build(BuildContext context) => AppLanguageScope(
    preference: language,
    onChanged: setLanguage,
    child: MaterialApp(
      locale: appLocaleForPreference(language),
      supportedLocales: supportedAppLocales,
      localeResolutionCallback: (locale, _) => resolveAppLocale(locale),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      title: 'SommoMemory',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: paper,
        fontFamily: 'Outfit',
        colorScheme: const ColorScheme.light(
          surface: paper,
          primary: popCobalt,
          onPrimary: paper,
          secondary: coral,
          onSecondary: ink,
          tertiary: popYellow,
          onTertiary: ink,
          onSurface: ink,
          outline: ink,
          surfaceTint: Colors.transparent,
        ),
        textTheme: const TextTheme(
          displayLarge: _fallbackTextStyle,
          displayMedium: _fallbackTextStyle,
          displaySmall: _fallbackTextStyle,
          headlineLarge: _fallbackTextStyle,
          headlineMedium: _fallbackTextStyle,
          headlineSmall: _fallbackTextStyle,
          titleLarge: _fallbackTextStyle,
          titleMedium: _fallbackTextStyle,
          titleSmall: _fallbackTextStyle,
          bodyLarge: TextStyle(color: ink, fontFamilyFallback: _systemFontFallback),
          bodyMedium: TextStyle(color: ink, fontFamilyFallback: _systemFontFallback),
          bodySmall: _fallbackTextStyle,
          labelLarge: _fallbackTextStyle,
          labelMedium: _fallbackTextStyle,
          labelSmall: _fallbackTextStyle,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: popYellow,
            foregroundColor: ink,
            disabledBackgroundColor: paper,
            disabledForegroundColor: muted,
            minimumSize: const Size(48, 56),
            side: const BorderSide(color: ink, width: 2),
            textStyle: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            backgroundColor: paper,
            foregroundColor: ink,
            minimumSize: const Size(48, 44),
            side: const BorderSide(color: ink, width: 2),
            textStyle: const TextStyle(
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            backgroundColor: paper,
            foregroundColor: popCobalt,
            textStyle: const TextStyle(
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            backgroundColor: paper,
            foregroundColor: ink,
            side: const BorderSide(color: ink, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
        ),
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith(
              (states) =>
                  states.contains(WidgetState.selected) ? popYellow : paper,
            ),
            foregroundColor: const WidgetStatePropertyAll(ink),
            side: const WidgetStatePropertyAll(
              BorderSide(color: ink, width: 1.5),
            ),
            textStyle: const WidgetStatePropertyAll(
              TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700),
            ),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: paper,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: ink, width: 2),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: paper,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: ink, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: ink, width: 2),
          ),
        ),
      ),
      home: Home(
        prefs: widget.prefs,
        economy: widget.economy,
        invites: widget.invites,
      ),
    ),
  );
}

class Home extends StatefulWidget {
  const Home({super.key, required this.prefs, this.economy, this.invites});
  final SharedPreferences prefs;
  final EconomyController? economy;
  final InviteLinks? invites;
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver {
  PlayMode mode = PlayMode.solo;
  int pairs = 8;
  String theme = 'garden';
  bool ranked = false;
  String arenaId = 'wild_valley';
  bool configuring = false;
  bool creatingBluetoothGame = false;
  bool starting = false;
  String? observedProfileId, observedProfileName;
  int navigationGeneration = 0;
  String? inviteCode;
  bool handlingInvite = false;
  String? queuedInvite;
  StreamSubscription<String>? inviteSubscription;
  StreamSubscription<void>? networkSubscription;
  final activeGameKey = GlobalKey<_GameScreenState>();
  late final TextEditingController name;
  final room = TextEditingController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final initialProfile = widget.economy?.profile;
    final pendingName =
        widget.prefs.getBool('name.localPending') == true &&
        (widget.prefs.getString('name.localProfile') == null ||
            initialProfile == null ||
            widget.prefs.getString('name.localProfile') == initialProfile.id);
    name = TextEditingController(
      text:
          !pendingName &&
              initialProfile != null &&
              (initialProfile.activated ||
                  initialProfile.displayName.isNotEmpty)
          ? initialProfile.displayName
          : widget.prefs.getString('name') ?? '',
    );
    observedProfileId = widget.economy?.profile?.id;
    observedProfileName = widget.economy?.profile?.displayName;
    arenaId = widget.economy?.profile?.currentArenaId ?? 'wild_valley';
    widget.economy?.addListener(economyChanged);
    networkSubscription = networkReconnects().listen((_) {
      if (widget.economy != null) unawaited(widget.economy!.sync());
    });
    final savedPairs = widget.prefs.getInt('game.pairs');
    if ([6, 8, 12, 18].contains(savedPairs)) pairs = savedPairs!;
    final savedTheme = widget.prefs.getString('game.collection');
    if (deckNames.containsKey(savedTheme)) theme = savedTheme!;
    final savedArena = widget.prefs.getString('game.friendlyArena');
    if (savedArena != null &&
        (widget.economy?.profile?.unlockedArenaIds ?? {'wild_valley'}).contains(
          savedArena,
        )) {
      arenaId = savedArena;
    }
    final selectedDeck = _arenaDeck(theme);
    if (selectedDeck?.arenaId != null && savedTheme != null) {
      final savedArenaIsUsable =
          savedArena != null &&
          (widget.economy?.profile?.unlockedArenaIds ?? {'wild_valley'})
              .contains(savedArena);
      if (savedArenaIsUsable && savedArena != selectedDeck!.arenaId) {
        theme = _firstUsableFreeTheme(arenaId) ?? theme;
      } else if (canUseFriendlyTheme(theme)) {
        arenaId = selectedDeck!.arenaId!;
      } else {
        theme = _firstUsableFreeTheme(arenaId) ?? theme;
      }
    } else if (selectedDeck?.arenaId == null) {
      // Paola is a standalone training deck; keep the last friendly arena.
    } else if (selectedDeck?.arenaId != arenaId) {
      theme = _firstUsableFreeTheme(arenaId) ?? theme;
    }
    _persistFriendlySelection();
    final invite =
        widget.invites?.takePendingRoomCode() ??
        roomCodeFromInviteUri(Uri.base);
    if (invite != null) {
      mode = PlayMode.online;
      room.text = invite;
      inviteCode = invite;
      configuring = true;
    }
    inviteSubscription = widget.invites?.roomCodes.listen((code) {
      widget.invites?.takePendingRoomCode();
      unawaited(handleInvite(code));
    });
    if (kIsWeb && Uri.base.queryParameters['account'] == 'delete') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.economy != null) profile(initialSection: 2);
      });
    }
    prefetch();
  }

  void prefetch() {
    final economy = widget.economy;
    if (economy != null && (mode == PlayMode.solo || mode == PlayMode.local)) {
      unawaited(
        economy.prefetchTicket(mode: mode.name, pairs: pairs, theme: theme),
      );
    }
  }

  Future<void> handleInvite(String code) async {
    if (!RegExp(r'^[A-Z0-9]{6}$').hasMatch(code) || !mounted) return;
    if (handlingInvite) {
      queuedInvite = code;
      return;
    }
    handlingInvite = true;
    try {
      final game = activeGameKey.currentState;
      if (game != null || starting) {
        final accept = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(tr(context, 'Aprire l’invito?')),
            content: Text(
              tr(
                context,
                'Stanza {code}. La partita in corso verrà abbandonata.',
                {'code': code},
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(tr(context, 'Resta')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(tr(context, 'Apri invito')),
              ),
            ],
          ),
        );
        if (accept != true || !mounted) return;
        await game?.leaveForInvite();
      }
      if (!mounted) return;
      navigationGeneration++;
      starting = false;
      Navigator.of(context).popUntil((route) => route.isFirst);
      setState(() {
        mode = PlayMode.online;
        room.text = code;
        inviteCode = code;
        configuring = true;
      });
    } finally {
      handlingInvite = false;
      final pending = queuedInvite;
      queuedInvite = null;
      if (pending != null && mounted && pending != inviteCode) {
        unawaited(handleInvite(pending));
      }
    }
  }

  void economyChanged() {
    if (!mounted) return;
    final profile = widget.economy?.profile;
    if (profile != null) {
      if (profile.id != observedProfileId ||
          profile.displayName != observedProfileName) {
        final firstEmptyGuest =
            observedProfileId == null &&
            !profile.activated &&
            profile.displayName.isEmpty;
        final profileSwitched =
            observedProfileId != null && observedProfileId != profile.id;
        if (profileSwitched) widget.prefs.remove('name.localPending');
        if (!firstEmptyGuest &&
            (profileSwitched ||
                widget.prefs.getBool('name.localPending') != true)) {
          name.text = profile.displayName;
        }
        observedProfileId = profile.id;
        observedProfileName = profile.displayName;
      }
      if (!profile.unlockedArenaIds.contains(arenaId)) {
        final themeDeck = _arenaDeck(theme);
        if (themeDeck?.arenaId != null &&
            widget.economy!.ownsDeck(theme) &&
            themeDeck!.arenaId == arenaId) {
          // Preserve a legacy purchase from a historically locked arena.
        } else {
          arenaId = profile.currentArenaId;
        }
      }
      if (ranked && widget.economy!.profileToken == null) ranked = false;
      if (!widget.economy!.ownsDeck(theme)) theme = 'garden';
      final selectedDeck = _arenaDeck(theme);
      if (selectedDeck?.arenaId != null && selectedDeck!.arenaId != arenaId) {
        if (profile.unlockedArenaIds.contains(arenaId)) {
          theme = _firstUsableFreeTheme(arenaId) ?? 'garden';
        } else {
          arenaId = profile.currentArenaId;
          theme = _firstUsableFreeTheme(arenaId) ?? 'garden';
        }
      }
    } else if (observedProfileId != null) {
      name.clear();
      observedProfileId = null;
      observedProfileName = null;
      if (!ProfileData.freeDecks.contains(theme)) theme = 'garden';
    }
    _persistFriendlySelection();
    setState(() {});
    prefetch();
  }

  void profile({int initialSection = 0}) {
    navigationGeneration++;
    setState(() => starting = false);
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ProfilePanel(
          economy: widget.economy!,
          initialSection: initialSection,
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.economy?.removeListener(economyChanged);
    unawaited(inviteSubscription?.cancel());
    unawaited(networkSubscription?.cancel());
    name.dispose();
    room.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.economy != null) {
      unawaited(widget.economy!.sync());
    }
  }

  void start({bool join = false, bool resume = false}) async {
    if (starting) return;
    if (mode == PlayMode.online &&
        !resume &&
        widget.prefs.getBool('room.activeRanked') == true &&
        widget.prefs.getString('room.code')?.isNotEmpty == true &&
        widget.prefs.getString('room.token')?.isNotEmpty == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              context,
              'Riprendi o abbandona la classificata in corso prima di entrare in un’altra stanza.',
            ),
          ),
          action: SnackBarAction(
            label: tr(context, 'Riprendi'),
            onPressed: () => start(resume: true),
          ),
        ),
      );
      return;
    }
    final rankedGame = mode == PlayMode.online && ranked && !join && !resume;
    if (rankedGame && !ArenaCatalog.instance.rankedEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              context,
              'La classificata sarà disponibile con un aggiornamento.',
            ),
          ),
        ),
      );
      return;
    }
    if (mode == PlayMode.online &&
        !rankedGame &&
        !join &&
        !resume &&
        !canUseFriendlyTheme(theme)) {
      chooseTheme();
      return;
    }
    if (!join &&
        !resume &&
        !rankedGame &&
        widget.economy != null &&
        !widget.economy!.ownsDeck(theme)) {
      chooseTheme();
      return;
    }
    final requestGeneration = ++navigationGeneration;
    final playMode = mode;
    final pairCount = rankedGame ? 12 : pairs;
    final collection = theme;
    setState(() => starting = true);
    try {
      GameTicket? ticket;
      if (playMode == PlayMode.solo || playMode == PlayMode.local) {
        ticket = await widget.economy?.takeTicket(
          mode: playMode.name,
          pairs: pairCount,
          theme: collection,
        );
        if (!mounted || requestGeneration != navigationGeneration) return;
        if (widget.economy != null && ticket == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                tr(
                  context,
                  'Puoi giocare; il premio non è disponibile per questa partita.',
                ),
              ),
            ),
          );
        }
      }
      widget.prefs.setString('name', name.text.trim());
      if (playMode == PlayMode.solo || playMode == PlayMode.local) {
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => GameScreen(
              key: activeGameKey,
              prefs: widget.prefs,
              pairs: pairCount,
              theme: collection,
              mode: playMode,
              economy: widget.economy,
              ticket: ticket,
            ),
          ),
        );
      } else if (playMode == PlayMode.online) {
        if (join && room.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr(context, 'Inserisci il codice della stanza')),
            ),
          );
          return;
        }
        final online = OnlineGame(widget.prefs);
        unawaited(
          online.open(
            resume
                ? null
                : join
                ? {
                    'type': 'join',
                    'supportedDecks': deckNames.keys.toList(),
                    if (widget.economy?.profileToken != null)
                      'profileToken': widget.economy!.profileToken,
                    'code': room.text.trim().toUpperCase(),
                    'name': name.text.trim().isEmpty
                        ? tr(context, 'Ospite')
                        : name.text.trim(),
                  }
                : {
                    'type': 'create',
                    'supportedDecks': deckNames.keys.toList(),
                    if (widget.economy?.profileToken != null)
                      'profileToken': widget.economy!.profileToken,
                    'name': name.text.trim().isEmpty
                        ? tr(context, 'Giocatore')
                        : name.text.trim(),
                    'matchType': rankedGame ? 'ranked' : 'friendly',
                    'arenaId': rankedGame
                        ? widget.economy?.profile?.currentArenaId ?? arenaId
                        : arenaId,
                    'pairs': pairCount,
                    if (!rankedGame) 'theme': collection,
                  },
          ),
        );
        if (!mounted || requestGeneration != navigationGeneration) return;
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => GameScreen(
              key: activeGameKey,
              prefs: widget.prefs,
              pairs: pairCount,
              theme: collection,
              mode: playMode,
              economy: widget.economy,
              ticket: ticket,
              online: online,
            ),
          ),
        );
        try {
          await widget.economy?.refresh();
        } catch (_) {
          // Keep the last cached profile when the account service is unavailable.
        }
        online.dispose();
      } else {
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => join
                ? BluetoothLobby.search(
                    gameKey: activeGameKey,
                    prefs: widget.prefs,
                    economy: widget.economy,
                    name: name.text.trim().isEmpty
                        ? tr(context, 'Giocatore')
                        : name.text.trim(),
                  )
                : BluetoothLobby.create(
                    gameKey: activeGameKey,
                    prefs: widget.prefs,
                    economy: widget.economy,
                    name: name.text.trim().isEmpty
                        ? tr(context, 'Giocatore')
                        : name.text.trim(),
                    pairs: pairCount,
                    theme: collection,
                  ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                context,
                widget.economy?.lastError ??
                    'Impossibile avviare la partita. Riprova.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted && requestGeneration == navigationGeneration) {
        setState(() => starting = false);
      }
    }
  }

  Future<void> editName() async {
    final previousName = name.text;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _TextEntryDialog(
        title: 'Nome giocatore',
        controller: name,
        action: 'Salva',
        hint: 'Giocatore',
        maxLength: 20,
        capitalization: TextCapitalization.words,
      ),
    );
    if (saved != true) name.text = previousName;
    widget.prefs.setString('name', name.text.trim());
    if (saved == true && widget.economy != null) {
      try {
        await widget.economy!.setDisplayName(name.text.trim());
        widget.prefs.remove('name.localPending');
        widget.prefs.remove('name.localProfile');
      } catch (_) {
        widget.prefs.setBool('name.localPending', true);
        final profileId = widget.economy!.profile?.id;
        if (profileId != null) {
          widget.prefs.setString('name.localProfile', profileId);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                tr(
                  context,
                  'Nome salvato su questo dispositivo. Il profilo online non è stato aggiornato.',
                ),
              ),
            ),
          );
        }
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> joinRoom() async {
    final join = await showDialog<bool>(
      context: context,
      builder: (context) => _TextEntryDialog(
        title: 'Codice stanza',
        controller: room,
        action: 'Entra',
        hint: 'ABC123',
        maxLength: 6,
        capitalization: TextCapitalization.characters,
      ),
    );
    if (join == true && mounted) start(join: true);
  }

  void choosePairs() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(tr(context, 'Numero di coppie')),
      content: SizedBox(
        width: 320,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in [6, 8, 12, 18])
              ChoiceChip(
                label: Text(tr(context, '{count} coppie', {'count': p})),
                selected: pairs == p,
                onSelected: (_) {
                  setState(() => pairs = p);
                  widget.prefs.setInt('game.pairs', p);
                  prefetch();
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    ),
  );

  Future<void> openInvitationInApp() async {
    final code = inviteCode;
    if (code == null) return;
    try {
      final opened = await launchUrl(
        inviteAppUriForRoom(code),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                context,
                'Puoi continuare nel browser con il codice della stanza.',
              ),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                context,
                'Puoi continuare nel browser con il codice della stanza.',
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> chooseTheme() async {
    final selected = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CollectionShop(selected: theme, economy: widget.economy),
      ),
    );
    if (!mounted || selected == null) return;
    final deck = _arenaDeck(selected);
    setState(() {
      theme = selected;
      if (deck?.arenaId != null) arenaId = deck!.arenaId!;
    });
    _persistFriendlySelection();
    prefetch();
  }

  Set<String> get unlockedArenaIds =>
      widget.economy?.profile?.unlockedArenaIds ?? const {'wild_valley'};

  Future<void> chooseArena() async {
    if (ranked) return;
    final selected = await ArenaPicker.show(
      context,
      selectedArenaId: arenaId,
      unlockedArenaIds: unlockedArenaIds,
      crowns: widget.economy?.profile?.crowns ?? 0,
    );
    if (!mounted || selected == null) return;
    setState(() => _selectFriendlyArena(selected));
    prefetch();
  }

  void _selectFriendlyArena(String selected) {
    arenaId = selected;
    if (_arenaDeck(theme)?.arenaId != selected) {
      theme = _firstUsableFreeTheme(selected) ?? theme;
    }
    _persistFriendlySelection();
  }

  ArenaDeck? _arenaDeck(String id) =>
      ArenaCatalog.instance.decks.where((deck) => deck.id == id).firstOrNull;

  String? _firstUsableFreeTheme(String id) => ArenaCatalog.instance.decks
      .where(
        (deck) =>
            deck.arenaId == id &&
            deck.price == 0 &&
            deck.isPlayable &&
            deckNames.containsKey(deck.id) &&
            canUseFriendlyTheme(deck.id),
      )
      .firstOrNull
      ?.id;

  void _persistFriendlySelection() {
    widget.prefs.setString('game.friendlyArena', arenaId);
    widget.prefs.setString('game.collection', theme);
  }

  bool canUseFriendlyTheme(String id) {
    final deck = ArenaCatalog.instance.decks
        .where((deck) => deck.id == id)
        .firstOrNull;
    if (deck == null || !deck.contentReady || !deckNames.containsKey(id)) {
      return false;
    }
    final owns =
        widget.economy?.ownsDeck(id) ?? ProfileData.freeDecks.contains(id);
    // The backend also preserves owned legacy purchases across arena changes.
    return owns;
  }

  void settings() => showDialog<void>(
    context: context,
    builder: (_) => _SettingsDialog(prefs: widget.prefs),
  );

  void backFromSetup() => setState(() {
    if (mode == PlayMode.bluetooth && creatingBluetoothGame) {
      creatingBluetoothGame = false;
    } else {
      configuring = false;
    }
  });

  @override
  Widget build(BuildContext context) {
    final modes = [
      (PlayMode.solo, Icons.person_outline_rounded, 'Singolo', 'Un giocatore'),
      (
        PlayMode.local,
        Icons.people_outline_rounded,
        'In due',
        'Un dispositivo',
      ),
      (PlayMode.online, Icons.public_rounded, 'Online', 'Due dispositivi'),
      if (BluetoothController.supported)
        (
          PlayMode.bluetooth,
          Icons.bluetooth_rounded,
          'Bluetooth',
          'Senza Internet',
        ),
    ];
    final modeTitle = switch (mode) {
      PlayMode.solo => 'Singolo',
      PlayMode.local => 'In due',
      PlayMode.online => 'Online',
      PlayMode.bluetooth => 'Bluetooth',
    };
    final canStartRanked =
        ArenaCatalog.instance.rankedEnabled &&
        widget.economy?.profileToken != null;
    return PopScope(
      canPop: !configuring,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) backFromSetup();
      },
      child: GameWorld(
        collection: theme,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: false,
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          if (configuring)
                            IconButton(
                              tooltip: tr(
                                context,
                                mode == PlayMode.bluetooth &&
                                        creatingBluetoothGame
                                    ? 'Scelta partita Bluetooth'
                                    : 'Scegli modalità',
                              ),
                              onPressed: backFromSetup,
                              icon: const Icon(Icons.arrow_back_rounded),
                            )
                          else ...[
                            const BrandMark(),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            child: Text(
                              tr(
                                context,
                                configuring ? modeTitle : 'SommoMemory',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: paper,
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -.6,
                              ),
                            ),
                          ),
                          if (widget.economy != null)
                            IconButton(
                              tooltip: tr(context, 'Profilo'),
                              onPressed: () => profile(),
                              icon: ProfileAvatar(
                                avatarId:
                                    widget.economy?.profile?.avatarId ?? 'fox',
                                accentId:
                                    widget.economy?.profile?.accentId ??
                                    'forest',
                                size: 28,
                              ),
                            ),
                          IconButton(
                            tooltip: tr(
                              context,
                              'Come si gioca e impostazioni',
                            ),
                            onPressed: settings,
                            icon: const Icon(Icons.tune_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (!configuring) ...[
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                tr(context, 'Modalità di gioco'),
                                style: TextStyle(
                                  color: paper,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (widget.economy != null)
                              GemBalance(
                                economy: widget.economy!,
                                onTap: chooseTheme,
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, c) {
                              final wide = c.maxWidth > c.maxHeight * 1.5;
                              final columns = wide ? modes.length : 2;
                              final rows = (modes.length / columns).ceil();
                              final showScene = !wide && c.maxHeight > 500;
                              final sceneHeight = showScene ? 120.0 : 0.0;
                              final tileWidth =
                                  (c.maxWidth - (columns - 1) * 12) / columns;
                              // Reserve space for the web store panel; scroll rather
                              // than compress the game cards on small viewports.
                              final tileHeight = math.max(
                                kIsWeb ? 132.0 : 0.0,
                                math.min(
                                  180.0,
                                  (c.maxHeight -
                                          sceneHeight -
                                          (rows - 1) * 12 -
                                          (kIsWeb ? 140 : 0)) /
                                      rows,
                                ),
                              );
                              final content = Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (showScene)
                                    SizedBox(
                                      height: sceneHeight,
                                      child: CollectionScene(
                                        collection: theme,
                                      ),
                                    ),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      for (final m in modes)
                                        SizedBox(
                                          width: tileWidth,
                                          height: tileHeight,
                                          child: ModeTile(
                                            icon: m.$2,
                                            title: m.$3,
                                            subtitle: m.$4,
                                            selected: false,
                                            onTap: () => setState(() {
                                              mode = m.$1;
                                              ranked = false;
                                              creatingBluetoothGame = false;
                                              if (m.$1 == PlayMode.online) {
                                                final legacyThemeArena =
                                                    _arenaDeck(
                                                          theme,
                                                        )?.arenaId ==
                                                        arenaId &&
                                                    widget.economy?.ownsDeck(
                                                          theme,
                                                        ) ==
                                                        true;
                                                final preferredArena =
                                                    unlockedArenaIds.contains(
                                                          arenaId,
                                                        ) ||
                                                        legacyThemeArena
                                                    ? arenaId
                                                    : widget
                                                              .economy
                                                              ?.profile
                                                              ?.currentArenaId ??
                                                          'wild_valley';
                                                _selectFriendlyArena(
                                                  preferredArena,
                                                );
                                              }
                                              configuring = true;
                                              prefetch();
                                            }),
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (kIsWeb)
                                    const Padding(
                                      padding: EdgeInsets.only(
                                        top: 20,
                                        bottom: 4,
                                      ),
                                      child: StoreLinks(),
                                    ),
                                ],
                              );
                              return Center(
                                child: kIsWeb
                                    ? SingleChildScrollView(child: content)
                                    : content,
                              );
                            },
                          ),
                        ),
                      ] else if (mode == PlayMode.bluetooth &&
                          !creatingBluetoothGame)
                        Expanded(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 440),
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    FilledButton.icon(
                                      onPressed: starting
                                          ? null
                                          : () => start(join: true),
                                      icon: const Icon(Icons.radar_rounded),
                                      label: Text(tr(context, 'Cerca partita')),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.fromLTRB(8, 8, 8, 20),
                                      child: Text(
                                        tr(
                                          context,
                                          'Entra in una partita vicina. Il mazzo e le coppie li sceglie chi crea.',
                                        ),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: paper),
                                      ),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: starting
                                          ? null
                                          : () => setState(
                                              () =>
                                                  creatingBluetoothGame = true,
                                            ),
                                      icon: const Icon(Icons.add_rounded),
                                      label: Text(tr(context, 'Crea partita')),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.fromLTRB(8, 8, 8, 16),
                                      child: Text(
                                        tr(
                                          context,
                                          'Scegli il mazzo e le coppie, poi aspetta l’altro giocatore.',
                                        ),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: paper),
                                      ),
                                    ),
                                    _OptionRow(
                                      icon: Icons.person_outline_rounded,
                                      label: 'Nome',
                                      value: name.text.trim().isEmpty
                                          ? tr(context, 'Giocatore')
                                          : name.text.trim(),
                                      onTap: editName,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, c) {
                              final options = Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: paper,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: ink, width: 2),
                                  boxShadow: const [
                                    BoxShadow(color: ink, offset: Offset(0, 4)),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (mode == PlayMode.online) ...[
                                      SegmentedButton<bool>(
                                        segments: [
                                          ButtonSegment(
                                            value: false,
                                            label: Text(
                                              tr(context, 'Amichevole'),
                                            ),
                                          ),
                                          ButtonSegment(
                                            value: true,
                                            label: Text(
                                              tr(context, 'Classificata'),
                                            ),
                                            enabled: canStartRanked,
                                          ),
                                        ],
                                        selected: {ranked},
                                        onSelectionChanged: (value) {
                                          if (value.first && !canStartRanked) {
                                            return;
                                          }
                                          setState(() {
                                            ranked = value.first;
                                            if (ranked) {
                                              arenaId =
                                                  widget
                                                      .economy
                                                      ?.profile
                                                      ?.currentArenaId ??
                                                  arenaId;
                                              pairs = 12;
                                            } else {
                                              final selectedDeck = _arenaDeck(
                                                theme,
                                              );
                                              if (selectedDeck?.arenaId !=
                                                  null) {
                                                arenaId =
                                                    selectedDeck!.arenaId!;
                                              }
                                              _persistFriendlySelection();
                                            }
                                          });
                                        },
                                      ),
                                      if (!ranked &&
                                          !ArenaCatalog.instance.rankedEnabled)
                                        Text(
                                          tr(
                                            context,
                                            'La modalità classificata via invito non è ancora attiva.',
                                          ),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: muted,
                                            fontSize: 12,
                                          ),
                                        ),
                                      if (!ranked &&
                                          ArenaCatalog.instance.rankedEnabled &&
                                          widget.economy?.profileToken == null)
                                        Text(
                                          tr(
                                            context,
                                            'Accedi a un profilo per creare una sfida classificata.',
                                          ),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: muted,
                                            fontSize: 12,
                                          ),
                                        ),
                                      if (ranked &&
                                          widget.economy?.profile != null)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 16,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.fromLTRB(
                                              12,
                                              4,
                                              12,
                                              8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: paper.withValues(
                                                alpha: .94,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: Border.all(color: line),
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                _OptionRow(
                                                  icon: Icons
                                                      .emoji_events_rounded,
                                                  label: 'Arena attuale',
                                                  value: ArenaCatalog
                                                      .instance
                                                      .arenas
                                                      .firstWhere(
                                                        (a) =>
                                                            a.id ==
                                                            widget
                                                                .economy!
                                                                .profile!
                                                                .currentArenaId,
                                                      )
                                                      .name,
                                                  onTap: null,
                                                ),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        bottom: 6,
                                                      ),
                                                  child: Text(
                                                    tr(
                                                      context,
                                                      '{crowns} corone · Record {record}',
                                                      {
                                                        'crowns': widget
                                                            .economy!
                                                            .profile!
                                                            .crowns,
                                                        'record': widget
                                                            .economy!
                                                            .profile!
                                                            .peakCrowns,
                                                      },
                                                    ),
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(
                                                      color: ink,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        )
                                      else if (ranked)
                                        Text(
                                          tr(
                                            context,
                                            'Accedi a un profilo per la classificata.',
                                          ),
                                          style: TextStyle(color: muted),
                                        ),
                                      if (!ranked) ...[
                                        ArenaJourneyTile(
                                          arenaId: arenaId,
                                          label: 'Arena amichevole',
                                          onTap: chooseArena,
                                        ),
                                        const SizedBox(height: 8),
                                        _CollectionTile(
                                          theme: theme,
                                          onTap: chooseTheme,
                                        ),
                                        _OptionRow(
                                          icon: Icons.grid_view_rounded,
                                          label: 'Coppie',
                                          value: '$pairs',
                                          onTap: choosePairs,
                                        ),
                                      ] else
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 14,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                            decoration: BoxDecoration(
                                              color: paper.withValues(
                                                alpha: .94,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              border: Border.all(color: line),
                                            ),
                                            child: Text(
                                              tr(
                                                context,
                                                '3 round · 12 coppie. Tabelloni identici per i due giocatori: vince chi usa meno tentativi totali.',
                                              ),
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: ink,
                                                fontSize: 13,
                                                height: 1.2,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ] else ...[
                                      ArenaJourneyTile(
                                        arenaId: arenaId,
                                        onTap: chooseArena,
                                      ),
                                      const SizedBox(height: 8),
                                      _OptionRow(
                                        icon: Icons.grid_view_rounded,
                                        label: 'Coppie',
                                        value: '$pairs',
                                        onTap: choosePairs,
                                      ),
                                      const SizedBox(height: 8),
                                      _CollectionTile(
                                        theme: theme,
                                        onTap: chooseTheme,
                                      ),
                                    ],
                                    if (mode == PlayMode.online ||
                                        mode == PlayMode.bluetooth) ...[
                                      const SizedBox(height: 8),
                                      _OptionRow(
                                        icon: Icons.person_outline_rounded,
                                        label: 'Nome',
                                        value: name.text.trim().isEmpty
                                            ? tr(context, 'Giocatore')
                                            : name.text.trim(),
                                        onTap: editName,
                                      ),
                                    ],
                                    if (mode == PlayMode.solo &&
                                        widget.prefs.getInt('best.$pairs') !=
                                            null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: Text(
                                          tr(
                                            context,
                                            'Record sul dispositivo: {count} tentativi',
                                            {
                                              'count': widget.prefs.getInt(
                                                'best.$pairs',
                                              )!,
                                            },
                                          ),
                                          style: const TextStyle(color: muted),
                                        ),
                                      ),
                                    if (mode == PlayMode.solo &&
                                        widget.economy != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              widget.economy!.offline
                                                  ? Icons.offline_pin_outlined
                                                  : Icons.cloud_done_outlined,
                                              size: 16,
                                              color: muted,
                                            ),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                tr(
                                                  context,
                                                  widget.economy!.offline ||
                                                          widget
                                                                  .economy!
                                                                  .pendingChanges >
                                                              0
                                                      ? 'Progressi salvati sul dispositivo · sincronizzazione automatica'
                                                      : 'Gemme e collezioni disponibili anche offline',
                                                ),
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: muted,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              );
                              final actions = Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  FilledButton.icon(
                                    onPressed: starting
                                        ? null
                                        : () => start(
                                            join:
                                                mode == PlayMode.online &&
                                                inviteCode != null,
                                          ),
                                    icon: const Icon(Icons.play_arrow_rounded),
                                    label: Text(
                                      tr(context, switch (mode) {
                                        PlayMode.online =>
                                          inviteCode == null
                                              ? 'Crea stanza'
                                              : 'Entra in $inviteCode',
                                        PlayMode.bluetooth => 'Crea partita',
                                        _ => 'Inizia partita',
                                      }),
                                    ),
                                  ),
                                  if (mode == PlayMode.online) ...[
                                    const SizedBox(height: 8),
                                    if (kIsWeb && inviteCode != null)
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextButton(
                                              onPressed: joinRoom,
                                              child: Text(
                                                tr(context, 'Altro codice'),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: TextButton.icon(
                                              onPressed: openInvitationInApp,
                                              icon: const Icon(
                                                Icons.open_in_new_rounded,
                                                size: 16,
                                              ),
                                              label: Text(
                                                tr(context, 'Apri nell’app'),
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    else
                                      OutlinedButton.icon(
                                        onPressed: joinRoom,
                                        icon: const Icon(Icons.login_rounded),
                                        label: Text(
                                          tr(context, 'Entra con un codice'),
                                        ),
                                      ),
                                    if (widget.prefs.getString('room.token') !=
                                        null)
                                      TextButton.icon(
                                        onPressed: () => start(resume: true),
                                        icon: const Icon(Icons.restore_rounded),
                                        label: Text(
                                          tr(context, 'Riprendi la stanza'),
                                        ),
                                      ),
                                  ],
                                ],
                              );
                              if (c.maxWidth > 540 && c.maxHeight < 430) {
                                return Row(
                                  children: [
                                    Expanded(
                                      child: SingleChildScrollView(
                                        child: Center(child: options),
                                      ),
                                    ),
                                    const SizedBox(width: 32),
                                    Expanded(
                                      child: SingleChildScrollView(
                                        child: Center(child: actions),
                                      ),
                                    ),
                                  ],
                                );
                              }
                              if (c.maxHeight <= 640) {
                                return Column(
                                  children: [
                                    Expanded(
                                      child: SingleChildScrollView(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: options,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    actions,
                                  ],
                                );
                              }
                              return Column(
                                children: [
                                  Expanded(
                                    child: CollectionScene(collection: theme),
                                  ),
                                  options,
                                  const SizedBox(height: 16),
                                  actions,
                                ],
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TextEntryDialog extends StatelessWidget {
  const _TextEntryDialog({
    required this.title,
    required this.controller,
    required this.action,
    required this.hint,
    required this.maxLength,
    required this.capitalization,
  });
  final String title, action, hint;
  final TextEditingController controller;
  final int maxLength;
  final TextCapitalization capitalization;
  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(16),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    tr(context, title),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(tr(context, 'Annulla')),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    maxLength: maxLength,
                    textCapitalization: capitalization,
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: tr(context, hint),
                    ),
                    onSubmitted: (_) => Navigator.pop(context, true),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(tr(context, action)),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });
  final IconData icon;
  final String label, value;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: paper,
    borderRadius: BorderRadius.circular(14),
    child: ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: ink, width: 1.5),
      ),
      leading: Icon(icon, color: teal),
      title: Text(
        tr(context, label),
        style: const TextStyle(fontSize: 12, color: muted),
      ),
      subtitle: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 17,
          color: ink,
          fontWeight: FontWeight.w800,
        ),
      ),
      trailing: onTap == null
          ? null
          : const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: onTap,
    ),
  );
}

class _SettingsDialog extends StatefulWidget {
  const _SettingsDialog({required this.prefs});
  final SharedPreferences prefs;
  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  int section = 0;
  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(16),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    tr(context, 'Impostazioni'),
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: tr(context, 'Chiudi'),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 0, label: Text(tr(context, 'Preferenze'))),
                ButtonSegment(value: 1, label: Text(tr(context, 'Regole'))),
                ButtonSegment(value: 2, label: Text(tr(context, 'Info'))),
              ],
              selected: {section},
              showSelectedIcon: false,
              onSelectionChanged: (v) => setState(() => section = v.first),
            ),
            const SizedBox(height: 16),
            if (section == 0) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tr(context, 'Lingua')),
                trailing: DropdownButton<String>(
                  key: const ValueKey('app-language'),
                  value:
                      AppLanguageScope.maybeOf(context)?.preference ?? 'auto',
                  items: [
                    for (final (value, label) in [
                      ('auto', 'Automatico'),
                      ('it', 'Italiano'),
                      ('en', 'Inglese'),
                    ])
                      DropdownMenuItem(
                        value: value,
                        child: Text(tr(context, label)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      AppLanguageScope.maybeOf(context)?.onChanged(value);
                    }
                  },
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tr(context, 'Suoni')),
                value: widget.prefs.getBool('sound') ?? true,
                onChanged: (v) {
                  widget.prefs.setBool('sound', v);
                  setState(() {});
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tr(context, 'Vibrazioni')),
                value: widget.prefs.getBool('haptics') ?? true,
                onChanged: (v) {
                  widget.prefs.setBool('haptics', v);
                  setState(() {});
                },
              ),
            ],
            if (section == 1)
              Text(
                tr(
                  context,
                  'Gira due carte e trova le coppie. Una coppia ti dà un altro turno; un errore passa il turno all’altro giocatore.\n\nOnline: condividi il codice stanza. Bluetooth: un telefono ospita, l’altro cerca la partita.',
                ),
              ),
            if (section == 2) ...[
              Text(
                tr(
                  context,
                  'SommoMemory · Michele Tagliabue\nLe partite locali restano sul dispositivo. Online vengono condivisi nome, mosse e stato stanza. Nessuna pubblicità o analisi di utilizzo.',
                ),
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 10),
              const SelectableText(
                'sommomemory.sommomi.cc/privacy\nmikitg.michele@gmail.com',
                style: TextStyle(fontSize: 13, color: teal),
              ),
              TextButton(
                onPressed: () => showLicensePage(
                  context: context,
                  applicationName: 'SommoMemory',
                ),
                child: Text(tr(context, 'Licenze')),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 34});
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Stack(
      children: [
        Positioned(
          left: 2,
          top: 1,
          child: Transform.rotate(
            angle: -.2,
            child: Container(
              width: size * .6,
              height: size * .8,
              decoration: BoxDecoration(
                color: coral,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: ink, width: 2),
              ),
            ),
          ),
        ),
        Positioned(
          right: 1,
          bottom: 1,
          child: Transform.rotate(
            angle: .16,
            child: Container(
              width: size * .6,
              height: size * .8,
              decoration: BoxDecoration(
                color: popYellow,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: ink, width: 2),
                boxShadow: const [BoxShadow(color: ink, offset: Offset(0, 2))],
              ),
              child: Icon(
                Icons.filter_none_rounded,
                color: ink,
                size: size * .34,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Color collectionColor(String theme) => deckAccent(theme);

class ModeTile extends StatelessWidget {
  const ModeTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final accent = switch (title) {
      'In due' => coral,
      'Online' => popSky,
      'Bluetooth' => paper,
      _ => popYellow,
    };
    return Semantics(
      selected: selected,
      button: true,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: ink, offset: Offset(0, 5))],
        ),
        child: Material(
          color: accent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ink, width: selected ? 3 : 2.5),
              ),
              child: LayoutBuilder(
                builder: (context, c) => Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Center(
                        child: _ModeEmblem(
                          icon: icon,
                          color: accent,
                          compact: c.maxHeight < 110,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tr(context, title),
                            style: const TextStyle(
                              fontSize: 18,
                              color: ink,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Icon(Icons.arrow_forward_rounded, color: ink, size: 18),
                      ],
                    ),
                    Text(
                      tr(context, subtitle),
                      style: const TextStyle(
                        fontSize: 12,
                        color: ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeEmblem extends StatelessWidget {
  const _ModeEmblem({
    required this.icon,
    required this.color,
    required this.compact,
  });
  final IconData icon;
  final Color color;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final players = icon == Icons.person_outline_rounded
        ? '1P'
        : icon == Icons.people_outline_rounded
        ? '2P'
        : null;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        width: compact ? 46 : 64,
        height: compact ? 42 : 60,
        decoration: BoxDecoration(
          color: paper,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: ink, width: 2),
          boxShadow: const [BoxShadow(color: ink, offset: Offset(0, 3))],
        ),
        alignment: Alignment.center,
        child: players != null
            ? Text(
                players,
                style: TextStyle(
                  color: ink,
                  fontSize: compact ? 20 : 27,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              )
            : Icon(icon, color: ink, size: compact ? 27 : 37),
      ),
    );
  }
}

class MemoryCard extends StatefulWidget {
  const MemoryCard({
    super.key,
    required this.index,
    required this.value,
    required this.theme,
    required this.matched,
    this.onTap,
    this.onConcealingChanged,
    this.onTurningChanged,
  });
  final int index;
  final int? value;
  final String theme;
  final bool matched;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onConcealingChanged;
  final ValueChanged<bool>? onTurningChanged;
  @override
  State<MemoryCard> createState() => _MemoryCardState();
}

class _MemoryCardState extends State<MemoryCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController flip;
  int? faceValue;
  bool reduceMotion = false;
  bool concealing = false;
  bool turning = false;
  @override
  void initState() {
    super.initState();
    faceValue = widget.value;
    flip = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      value: widget.value == null ? 0 : 1,
    )..addListener(_checkConcealed);
    // A remounted card is already at its target face, including after rotation.
    widget.onTurningChanged?.call(false);
  }

  void _checkConcealed() {
    final target = widget.value == null ? 0.0 : 1.0;
    if (turning && flip.value == target) {
      turning = false;
      widget.onTurningChanged?.call(false);
    }
    if (concealing && flip.value == 0) {
      concealing = false;
      widget.onConcealingChanged?.call(false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) flip.value = widget.value == null ? 0 : 1;
  }

  @override
  void didUpdateWidget(MemoryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != null) faceValue = widget.value;
    if ((oldWidget.value == null) != (widget.value == null)) {
      final target = widget.value == null ? 0.0 : 1.0;
      if (target == 1 && concealing) {
        // A newer remote reveal supersedes this card's unfinished conceal.
        concealing = false;
        widget.onConcealingChanged?.call(false);
      }
      if (target == 0 && flip.value > 0 && !concealing) {
        concealing = true;
        widget.onConcealingChanged?.call(true);
      }
      if (flip.value != target && !turning) {
        turning = true;
        widget.onTurningChanged?.call(true);
      }
      if (reduceMotion) {
        flip.value = target;
      } else {
        flip.animateTo(target, curve: Curves.easeInOutCubic);
      }
    }
  }

  @override
  void dispose() {
    if (turning) widget.onTurningChanged?.call(false);
    if (concealing) widget.onConcealingChanged?.call(false);
    flip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.matched
        ? tr(context, 'Coppia trovata')
        : widget.value != null
        ? tr(context, 'Carta {index}, {symbol}', {
            'index': widget.index + 1,
            'symbol': tr(
              context,
              deckLabel(widget.theme, widget.value!) ??
                  tr(context, 'simbolo {number}', {
                    'number': widget.value! + 1,
                  }),
            ),
          })
        : tr(context, 'Carta {index}, coperta', {'index': widget.index + 1}),
    button: widget.onTap != null,
    child: AnimatedBuilder(
      animation: flip,
      builder: (context, _) {
        final front = flip.value >= .5;
        final angle = flip.value * math.pi;
        return Transform(
          key: ValueKey('flip-${widget.index}'),
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, .0015)
            ..rotateY(angle),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationY(front ? math.pi : 0),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap == null || flip.isAnimating
                    ? null
                    : widget.onTap,
                borderRadius: BorderRadius.circular(13),
                child: AnimatedContainer(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  decoration: BoxDecoration(
                    color: front
                        ? (widget.matched ? popYellow : paper)
                        : popCobalt,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: ink, width: 2.2),
                    boxShadow: [
                      BoxShadow(color: ink, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final side = math.min(c.maxWidth, c.maxHeight);
                      if (front && faceValue != null) {
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            Padding(
                              padding: EdgeInsets.all(side * .12),
                              child: _CollectionSymbol(
                                theme: widget.theme,
                                value: faceValue!,
                                size: side * .66,
                              ),
                            ),
                            if (widget.matched)
                              Positioned(
                                right: 2,
                                bottom: 2,
                                child: Icon(
                                  Icons.check_circle_rounded,
                                  color: ink,
                                  size: math.max(11, side * .19),
                                ),
                              ),
                          ],
                        );
                      }
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: CustomPaint(
                          painter: BackPattern(theme: widget.theme),
                          child: Center(
                            child: Container(
                              width: side * .56,
                              height: side * .56,
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                shape: BoxShape.circle,
                                border: Border.all(color: popYellow, width: 2),
                              ),
                              child: ExcludeSemantics(
                                child: Icon(
                                  deckBackIcon(widget.theme),
                                  color: popYellow,
                                  size: side * .32,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _CollectionSymbol extends StatelessWidget {
  const _CollectionSymbol({
    required this.theme,
    required this.value,
    required this.size,
  });
  final String theme;
  final int value;
  final double size;
  @override
  Widget build(BuildContext context) {
    if (theme == 'paola') {
      return ExcludeSemantics(
        child: DeckArtwork(collection: theme, value: value),
      );
    }
    final path = deckAsset(theme, value);
    if (path != null) {
      return Image.asset(
        path,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        excludeFromSemantics: true,
      );
    }
    return Icon(
      (symbols[theme] ?? symbols['garden']!)[value % 18],
      color: symbolColors[value % symbolColors.length],
      size: size,
    );
  }
}

class _CollectionTile extends StatelessWidget {
  const _CollectionTile({required this.theme, required this.onTap});
  final String theme;
  final VoidCallback onTap;
  static const selected = false;
  @override
  Widget build(BuildContext context) {
    final color = collectionColor(theme);
    return Material(
      color: paper,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 76,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ink, width: 1.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      tr(context, 'Collezione'),
                      style: TextStyle(fontSize: 11, color: muted),
                    ),
                    Text(
                      tr(context, deckNames[theme]!),
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 112,
                height: 58,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Positioned(
                        left: i * 31.0,
                        top: i == 1 ? 0 : 7,
                        child: Transform.rotate(
                          angle: (i - 1) * .16,
                          child: Container(
                            width: 44,
                            height: 49,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: paper,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: ink, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: ink,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: _CollectionSymbol(
                              theme: theme,
                              value: i,
                              size: 35,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.chevron_right_rounded,
                color: color,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BackPattern extends CustomPainter {
  const BackPattern({this.theme = 'garden'});
  final String theme;
  @override
  void paint(Canvas canvas, Size size) {
    final world = deckWorldTheme(theme);
    final paint = Paint()
      ..color = paper.withValues(alpha: .18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (double x = 8; x < size.width; x += 19) {
      for (double y = 8; y < size.height; y += 20) {
        if (world == 'cosmos') {
          canvas.drawLine(Offset(x - 2, y), Offset(x + 2, y), paint);
          canvas.drawLine(Offset(x, y - 2), Offset(x, y + 2), paint);
        } else if (world == 'ocean') {
          canvas.drawArc(
            Rect.fromCircle(center: Offset(x, y), radius: 5),
            0,
            math.pi,
            false,
            paint,
          );
        } else {
          canvas.drawOval(
            Rect.fromCenter(center: Offset(x, y), width: 4, height: 7),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(BackPattern oldDelegate) => oldDelegate.theme != theme;
}

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.prefs,
    required this.pairs,
    required this.theme,
    required this.mode,
    this.online,
    this.bluetooth,
    this.economy,
    this.ticket,
    this.feedback,
  });
  final SharedPreferences prefs;
  final int pairs;
  final String theme;
  final PlayMode mode;
  final OnlineGame? online;
  final BluetoothController? bluetooth;
  final EconomyController? economy;
  final GameTicket? ticket;
  final GameFeedback? feedback;
  @override
  State<GameScreen> createState() => _GameScreenState();
}

/// Immutable presentation revision. Authority keeps running independently.
class _BoardFrame {
  _BoardFrame({
    required List<int?> cards,
    required Set<int> matched,
    required List<int> scores,
    required List<Map<String, dynamic>> players,
    required this.turn,
    required this.moves,
    required this.finished,
    required this.theme,
    this.winnerId,
    this.finishReason,
    this.roundId,
    this.matchId,
    this.matchType = 'friendly',
    this.arenaId,
    this.roundIndex = 1,
    this.roundCount = 1,
    this.phase = 'playing',
    List<String> roundDecks = const [],
    List<Map<String, dynamic>> roundResults = const [],
    Map<String, dynamic> totalScores = const {},
    List<String> roundReady = const [],
    Map<String, dynamic> totalAttempts = const {},
    Map<String, dynamic>? rewardReceipt,
    Map<String, dynamic>? rewardProof,
  }) : rewardReceipt = rewardReceipt == null
           ? null
           : Map.unmodifiable(rewardReceipt),
       rewardProof = rewardProof == null
           ? null
           : Map.unmodifiable({
               ...rewardProof,
               if (rewardProof['moves'] is List)
                 'moves': List.unmodifiable(rewardProof['moves'] as List),
             }),
       cards = List.unmodifiable(cards),
       roundDecks = List.unmodifiable(roundDecks),
       roundResults = List.unmodifiable(
         roundResults.map((result) {
           final copy = Map<String, dynamic>.from(result);
           if (copy['scores'] is Map) {
             copy['scores'] = Map<String, dynamic>.unmodifiable(
               Map<String, dynamic>.from(copy['scores'] as Map),
             );
           }
           return Map<String, dynamic>.unmodifiable(copy);
         }),
       ),
       totalScores = Map.unmodifiable(totalScores),
       totalAttempts = Map.unmodifiable(totalAttempts),
       roundReady = List.unmodifiable(roundReady),
       matched = Set.unmodifiable(matched),
       scores = List.unmodifiable(scores),
       players = List.unmodifiable(
         players.map((p) => Map<String, dynamic>.unmodifiable(p)),
       );
  final List<int?> cards;
  final Set<int> matched;
  final List<int> scores;
  final List<Map<String, dynamic>> players;
  final Object? turn;
  final int moves;
  final bool finished;
  final String theme;
  final String? winnerId, finishReason, roundId;
  final String? matchId, arenaId;
  final String matchType, phase;
  final int roundIndex, roundCount;
  final List<String> roundDecks, roundReady;
  final List<Map<String, dynamic>> roundResults;
  final Map<String, dynamic> totalScores;
  final Map<String, dynamic> totalAttempts;
  final Map<String, dynamic>? rewardReceipt, rewardProof;
  bool sameCards(_BoardFrame other) =>
      theme == other.theme &&
      roundId == other.roundId &&
      matchId == other.matchId &&
      listEquals(cards, other.cards);
  bool sameEvents(_BoardFrame other) =>
      turn == other.turn &&
      moves == other.moves &&
      finished == other.finished &&
      winnerId == other.winnerId &&
      finishReason == other.finishReason &&
      roundId == other.roundId &&
      matchId == other.matchId &&
      matchType == other.matchType &&
      arenaId == other.arenaId &&
      roundIndex == other.roundIndex &&
      roundCount == other.roundCount &&
      phase == other.phase &&
      listEquals(roundDecks, other.roundDecks) &&
      listEquals(roundReady, other.roundReady) &&
      mapEquals(totalScores, other.totalScores) &&
      mapEquals(totalAttempts, other.totalAttempts) &&
      roundResults.length == other.roundResults.length &&
      List.generate(
        roundResults.length,
        (index) =>
            _sameRoundResult(roundResults[index], other.roundResults[index]),
      ).every((same) => same) &&
      mapEquals(rewardReceipt, other.rewardReceipt) &&
      (rewardProof?['ticketId'] == other.rewardProof?['ticketId']) &&
      listEquals(
        rewardProof?['moves'] as List?,
        other.rewardProof?['moves'] as List?,
      ) &&
      setEquals(matched, other.matched) &&
      listEquals(scores, other.scores) &&
      players.length == other.players.length &&
      List.generate(
        players.length,
        (i) => mapEquals(players[i], other.players[i]),
      ).every((same) => same);

  bool _sameRoundResult(Map<String, dynamic> a, Map<String, dynamic> b) =>
      a['round'] == b['round'] &&
      a['theme'] == b['theme'] &&
      a['winnerId'] == b['winnerId'] &&
      mapEquals(a['scores'] as Map?, b['scores'] as Map?) &&
      mapEquals(a['attempts'] as Map?, b['attempts'] as Map?);
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late final GameFeedback gameFeedback;
  LobbyVoice? lobbyVoice;
  bool feedbackForeground = true;
  bool muteFeedbackUntilSettled = false;
  LocalGame? local;
  GameTicket? activeTicket;
  final List<int> acceptedMoves = [];
  bool rewardRequested = false;
  String? rewardMessage;
  bool replayStarting = false;
  bool recorded = false;
  final Set<int> concealingCards = {};
  final Set<int> turningCards = {};
  final List<_BoardFrame> pendingFrames = [];
  _BoardFrame? targetFrame, displayedEvents, lastAuthorityFrame;
  bool presentationScheduled = false;
  bool yieldedRoundFinishedForNextSequence = false;
  bool reduceMotion = false;
  int presentationGeneration = 0;
  bool get boardLocked =>
      turningCards.isNotEmpty ||
      concealingCards.isNotEmpty ||
      pendingFrames.isNotEmpty ||
      local?.locked == true ||
      local?.finished == true ||
      net?['lockedUntil'] != null ||
      network && net?['phase'] != 'playing';

  _BoardFrame captureFrame() {
    final game = local;
    final state = net;
    final players = (state?['players'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    return _BoardFrame(
      cards: game != null
          ? [
              for (var i = 0; i < game.deck.length; i++)
                game.matched.contains(i) || game.selected.contains(i)
                    ? game.deck[i]
                    : null,
            ]
          : (state?['cards'] as List? ?? [])
                .map((v) => v == null ? null : int.parse(v.toString()))
                .toList(),
      matched: game != null
          ? game.matched
          : (state?['matched'] as List? ?? []).cast<int>().toSet(),
      scores: game != null
          ? game.scores
          : [for (final p in players) (p['score'] as num?)?.toInt() ?? 0],
      players: players,
      turn: game != null ? game.turn : state?['turn'],
      moves: game?.moves ?? 0,
      finished: game?.finished ?? state?['phase'] == 'finished',
      theme: state?['theme'] as String? ?? widget.theme,
      winnerId: state?['winnerId'] as String?,
      finishReason: state?['finishReason'] as String?,
      roundId: state?['roundId']?.toString(),
      matchId: state?['matchId']?.toString(),
      matchType: state?['matchType'] as String? ?? 'friendly',
      arenaId: state?['arenaId'] as String?,
      roundIndex: state?['roundIndex'] as int? ?? 1,
      roundCount: state?['roundCount'] as int? ?? 1,
      phase: state?['phase'] as String? ?? 'playing',
      roundDecks: (state?['roundDecks'] as List? ?? const []).cast<String>(),
      roundResults: (state?['roundResults'] as List? ?? const [])
          .whereType<Map>()
          .map((value) => Map<String, dynamic>.from(value))
          .toList(),
      totalScores: Map<String, dynamic>.from(
        state?['totalScores'] as Map? ?? const {},
      ),
      totalAttempts: Map<String, dynamic>.from(
        state?['totalAttempts'] as Map? ?? const {},
      ),
      roundReady: (state?['roundReady'] as List? ?? const []).cast<String>(),
      rewardReceipt: (state?['rewards'] as Map?)?[playerId] is Map
          ? Map<String, dynamic>.from(
              (state!['rewards'] as Map)[playerId] as Map,
            )
          : null,
      rewardProof: state?['reward'] is Map
          ? Map<String, dynamic>.from(state!['reward'] as Map)
          : null,
    );
  }

  void resetPresentation(_BoardFrame frame, {bool preserveAuthority = false}) {
    final authority = lastAuthorityFrame;
    rewardRequested = false;
    rewardMessage = null;
    presentationGeneration++;
    presentationScheduled = false;
    yieldedRoundFinishedForNextSequence = false;
    turningCards.clear();
    concealingCards.clear();
    pendingFrames.clear();
    targetFrame = displayedEvents = frame;
    lastAuthorityFrame = preserveAuthority ? authority : frame;
  }

  bool isNewSequence(_BoardFrame before, _BoardFrame after) =>
      (before.finished && after.phase == 'playing') ||
      (before.roundId != null &&
          after.roundId != null &&
          before.roundId != after.roundId) ||
      (before.matchId != null &&
          after.matchId != null &&
          before.matchId != after.matchId);

  void applyFrame(_BoardFrame frame) {
    if (targetFrame != null && isNewSequence(targetFrame!, frame)) {
      resetPresentation(frame, preserveAuthority: true);
      muteFeedbackUntilSettled = false;
    } else {
      activateFrame(frame);
    }
  }

  void activateFrame(_BoardFrame frame) {
    final previous = targetFrame;
    targetFrame = frame;
    if (!muteFeedbackUntilSettled &&
        previous != null &&
        previous.cards.isNotEmpty &&
        previous.cards.length == frame.cards.length &&
        List.generate(
          frame.cards.length,
          (i) => i,
        ).any((i) => previous.cards[i] == null && frame.cards[i] != null)) {
      gameFeedback.play(GameFeedbackEvent.flip);
    }
    if (!reduceMotion &&
        previous != null &&
        previous.cards.length == frame.cards.length) {
      for (var i = 0; i < frame.cards.length; i++) {
        if ((previous.cards[i] == null) != (frame.cards[i] == null)) {
          turningCards.add(i);
        }
      }
    }
    if (turningCards.isEmpty) displayFrame(frame);
  }

  /// Outcomes belong to the settled presentation, never the authority's head.
  void displayFrame(_BoardFrame frame) {
    final previous = displayedEvents;
    displayedEvents = frame;
    if (muteFeedbackUntilSettled) {
      if (pendingFrames.isEmpty &&
          turningCards.isEmpty &&
          concealingCards.isEmpty) {
        muteFeedbackUntilSettled = false;
      }
      return;
    }
    if (previous == null ||
        previous.cards.isEmpty ||
        previous.cards.length != frame.cards.length ||
        previous.roundId != frame.roundId) {
      return;
    }
    if (frame.matched.length > previous.matched.length) {
      gameFeedback.play(GameFeedbackEvent.match);
    } else {
      final revealed = [
        for (var i = 0; i < frame.cards.length; i++)
          if (frame.cards[i] != null && !frame.matched.contains(i)) i,
      ];
      if (revealed.length == 2 &&
          frame.cards[revealed[0]] != frame.cards[revealed[1]] &&
          revealed.any((i) => previous.cards[i] != frame.cards[i])) {
        gameFeedback.play(GameFeedbackEvent.mismatch);
      }
    }
    if (!frame.finished &&
        previous.turn != null &&
        frame.turn != null &&
        frame.turn != previous.turn) {
      gameFeedback.play(GameFeedbackEvent.turn);
    }
  }

  void receiveFrame(_BoardFrame frame) {
    if (targetFrame == null) {
      resetPresentation(frame);
      return;
    }
    lastAuthorityFrame = frame;
    if (isNewSequence(targetFrame!, frame) &&
        targetFrame!.phase == 'roundFinished') {
      pendingFrames.add(frame);
      yieldedRoundFinishedForNextSequence = false;
      if (turningCards.isEmpty && concealingCards.isEmpty) {
        schedulePresentation();
      }
      return;
    }
    final latest = pendingFrames.isEmpty ? targetFrame! : pendingFrames.last;
    if (latest.sameCards(frame)) {
      if (latest.sameEvents(frame)) {
        return; // Ignore unchanged heartbeats/clock ticks.
      }
      if (pendingFrames.isNotEmpty) {
        pendingFrames[pendingFrames.length - 1] = frame;
      } else {
        targetFrame = frame;
        if (turningCards.isEmpty && concealingCards.isEmpty) {
          displayFrame(frame);
        }
      }
    } else if (turningCards.isNotEmpty ||
        concealingCards.isNotEmpty ||
        pendingFrames.isNotEmpty) {
      pendingFrames.add(frame);
    } else {
      applyFrame(frame);
    }
  }

  void advancePresentation() {
    if (turningCards.isNotEmpty || concealingCards.isNotEmpty) {
      schedulePresentation();
      return;
    }
    displayFrame(targetFrame!);
    if (targetFrame!.phase == 'roundFinished' &&
        pendingFrames.any((frame) => isNewSequence(targetFrame!, frame)) &&
        !yieldedRoundFinishedForNextSequence) {
      yieldedRoundFinishedForNextSequence = true;
      schedulePresentation();
      return;
    }
    while (pendingFrames.isNotEmpty) {
      final next = pendingFrames.removeAt(0);
      if (isNewSequence(targetFrame!, next)) {
        final queued = List<_BoardFrame>.of(pendingFrames);
        resetPresentation(next, preserveAuthority: true);
        muteFeedbackUntilSettled = false;
        pendingFrames.addAll(queued);
        continue;
      }
      activateFrame(next);
      if (turningCards.isNotEmpty) return;
      if (next.phase == 'roundFinished' &&
          pendingFrames.any((frame) => isNewSequence(next, frame)) &&
          !yieldedRoundFinishedForNextSequence) {
        yieldedRoundFinishedForNextSequence = true;
        schedulePresentation();
        return;
      }
    }
  }

  void schedulePresentation() {
    if (presentationScheduled || !mounted) return;
    presentationScheduled = true;
    final generation = presentationGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != presentationGeneration) return;
      presentationScheduled = false;
      setState(advancePresentation);
    });
  }

  void cardTurningChanged(int index, bool turning, int generation) {
    if (generation != presentationGeneration) return;
    final changed = turning
        ? turningCards.add(index)
        : turningCards.remove(index);
    if (changed) schedulePresentation();
  }

  void cardConcealingChanged(int index, bool concealing, int generation) {
    if (generation != presentationGeneration) return;
    final changed = concealing
        ? concealingCards.add(index)
        : concealingCards.remove(index);
    if (changed) schedulePresentation();
  }

  Map<String, dynamic>? get net =>
      widget.online?.state ?? widget.bluetooth?.state;
  String? get playerId => widget.online?.playerId ?? widget.bluetooth?.playerId;
  bool get network => widget.online != null || widget.bluetooth != null;
  bool get connected =>
      widget.online?.connected ?? widget.bluetooth?.connected ?? true;
  String get gameTheme =>
      targetFrame?.theme ?? net?['theme'] as String? ?? widget.theme;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    gameFeedback = widget.feedback ?? GameFeedback(widget.prefs);
    feedbackForeground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    gameFeedback.setActive(feedbackForeground);
    activeTicket = widget.ticket;
    if (!network) _startLocal();
    resetPresentation(captureFrame());
    if (widget.online != null) {
      lobbyVoice = LobbyVoice(widget.online!)..addListener(update);
    }
    widget.online?.addListener(update);
    widget.bluetooth?.addListener(update);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    reduceMotion = MediaQuery.disableAnimationsOf(context);
  }

  void _startLocal() {
    acceptedMoves.clear();
    rewardRequested = false;
    rewardMessage = null;
    concealingCards.clear();
    local?.removeListener(update);
    local?.dispose();
    local = LocalGame(
      pairs: widget.pairs,
      board: activeTicket?.board,
      twoPlayers: widget.mode == PlayMode.local,
    )..addListener(update);
    recorded = false;
    resetPresentation(captureFrame());
  }

  void update() {
    if (!mounted) return;
    if (network && !connected) muteFeedbackUntilSettled = true;
    gameFeedback.setActive(feedbackForeground && (!network || connected));
    receiveFrame(captureFrame());
    if (local?.finished == true && !recorded) {
      recorded = true;
      if (widget.mode == PlayMode.solo) {
        final key = 'best.${widget.pairs}';
        final best = widget.prefs.getInt(key);
        if (best == null || local!.moves < best) {
          widget.prefs.setInt(key, local!.moves);
        }
      }
    }
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    feedbackForeground = state == AppLifecycleState.resumed;
    if (!feedbackForeground) muteFeedbackUntilSettled = true;
    gameFeedback.setActive(feedbackForeground && (!network || connected));
    lobbyVoice?.setForeground(feedbackForeground);
    if (state == AppLifecycleState.resumed &&
        widget.online != null &&
        !widget.online!.terminalError &&
        !widget.online!.connected) {
      widget.online!.open(null);
    }
  }

  @override
  void dispose() {
    if (widget.feedback == null) gameFeedback.dispose();
    presentationGeneration++;
    pendingFrames.clear();
    WidgetsBinding.instance.removeObserver(this);
    local?.dispose();
    lobbyVoice?.removeListener(update);
    lobbyVoice?.dispose();
    widget.online?.removeListener(update);
    widget.bluetooth?.removeListener(update);
    super.dispose();
  }

  Future<void> exit() async {
    if (widget.online != null && net?['phase'] == 'waiting') {
      await exitLobby();
      return;
    }
    if (network && displayedEvents?.finished == true) {
      if (mounted) Navigator.pop(context);
      return;
    }
    if (network && net == null) {
      await widget.online?.leave();
      await widget.bluetooth?.leave();
      if (mounted) Navigator.pop(context);
      return;
    }
    if (!network && local!.finished) {
      if (mounted) Navigator.pop(context);
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr(context, 'Una pausa?')),
        content: Text(
          network
              ? tr(
                  context,
                  'Se abbandoni, l’altro giocatore vince la partita. Online puoi anche chiudere e riconnetterti entro 90 secondi.',
                )
              : tr(context, 'La partita in corso non verrà salvata.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr(context, 'Resta')),
          ),
          if (widget.online != null)
            TextButton(
              onPressed: () => Navigator.pop(context, 'pause'),
              child: Text(tr(context, 'Pausa')),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'leave'),
            child: Text(tr(context, 'Abbandona')),
          ),
        ],
      ),
    );
    if (choice == null) return;
    if (choice == 'leave') {
      await widget.online?.leave();
      await widget.bluetooth?.leave();
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> exitLobby() async {
    await widget.online?.leave();
    if (mounted) Navigator.pop(context);
  }

  void flip(int i, {required int generation}) {
    if (generation != presentationGeneration || boardLocked) return;
    final ranked = net?['matchType'] == 'ranked';
    final ownRankedPlayer = ranked
        ? ((net?['players'] as List?) ?? [])
              .whereType<Map>()
              .where((player) => player['id'] == playerId)
              .firstOrNull
        : null;
    if (network &&
        (!connected ||
            net?['phase'] != 'playing' ||
            (!ranked && net?['turn'] != playerId) ||
            (ranked && ownRankedPlayer?['roundComplete'] == true) ||
            ((net?['players'] as List?) ?? []).any(
              (p) => p['connected'] != true,
            ))) {
      return;
    }
    muteFeedbackUntilSettled = false;
    gameFeedback.unlock();
    if (local != null) {
      if (local!.flip(i)) acceptedMoves.add(i);
    } else if (widget.online != null) {
      widget.online!.flip(i);
    } else {
      widget.bluetooth!.flip(i);
    }
  }

  Future<void> replay() async {
    if (replayStarting) return;
    if (local != null) {
      setState(() => replayStarting = true);
      try {
        final next = await widget.economy?.takeTicket(
          mode: widget.mode.name,
          pairs: widget.pairs,
          theme: widget.theme,
        );
        if (!mounted) return;
        setState(() {
          activeTicket = next;
          _startLocal();
        });
      } finally {
        if (mounted) setState(() => replayStarting = false);
      }
    } else if (widget.online != null) {
      widget.online!.rematch();
    } else {
      widget.bluetooth!.rematch();
    }
  }

  Future<void> leaveForInvite() async {
    await widget.online?.leave();
    await widget.bluetooth?.leave();
  }

  Future<void> awardFinishedGame(
    int generation,
    GameTicket? ticket,
    List<int> moves,
    Map<String, dynamic>? receipt,
    Map<String, dynamic>? proof,
    bool bluetoothHost,
  ) async {
    final economy = widget.economy;
    if (economy == null) return;
    String? message;
    try {
      if (local != null && ticket != null) {
        final result = await economy.claimGame(ticket: ticket, moves: moves);
        message = result == null
            ? economy.pendingRewards > 0
                  ? 'Premio in attesa di sincronizzazione'
                  : 'Premio non disponibile'
            : result.granted
            ? '+${result.gems} gemme'
            : 'Premio già registrato';
      } else if (widget.bluetooth != null &&
          proof?['ticketId'] is String &&
          proof?['moves'] is List) {
        final result = await economy.claimProof(
          ticketId: proof!['ticketId'] as String,
          moves: (proof['moves'] as List).cast<int>(),
          guestClaimToken: bluetoothHost
              ? null
              : proof['guestClaimToken'] as String?,
        );
        message = result == null
            ? economy.pendingRewards > 0
                  ? 'Premio in attesa di sincronizzazione'
                  : 'Premio non disponibile'
            : result.granted
            ? '+${result.gems} gemme'
            : 'Premio già registrato';
      } else if (widget.online != null) {
        await economy.refresh();
        final crownsDelta = receipt?['crownsDelta'];
        final crownText = crownsDelta is int
            ? '${crownsDelta > 0 ? '+' : ''}$crownsDelta corone'
            : null;
        final gemText = receipt?['granted'] == true
            ? '+${receipt!['gems']} gemme'
            : economy.offline
            ? 'Saldo in attesa di sincronizzazione'
            : 'Saldo aggiornato · ${economy.gems} gemme';
        message = crownText == null ? gemText : '$crownText · $gemText';
      } else if (local != null) {
        message = 'Partita senza premio';
      }
    } catch (_) {
      message = economy.pendingRewards > 0
          ? 'Premio in attesa di sincronizzazione'
          : 'Premio non disponibile';
    }
    if (mounted && generation == presentationGeneration) {
      setState(() => rewardMessage = message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = net;
    final generation = presentationGeneration;
    final waiting = network && (s == null || s['phase'] == 'waiting');
    final events = displayedEvents!;
    final finished = events.finished;
    if (finished &&
        !rewardRequested &&
        widget.economy != null &&
        (widget.online == null || events.rewardReceipt != null)) {
      rewardRequested = true;
      final ticket = activeTicket;
      final moves = List<int>.of(acceptedMoves);
      final receipt = events.rewardReceipt;
      final proof = events.rewardProof;
      final bluetoothHost = widget.bluetooth?.isHosting == true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && generation == presentationGeneration) {
          unawaited(
            awardFinishedGame(
              generation,
              ticket,
              moves,
              receipt,
              proof,
              bluetoothHost,
            ),
          );
        }
      });
    }
    final players = events.players;
    final authorityPlayers =
        (s?['players'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final active = network
        ? (s?['matchType'] == 'ranked' || s?['turn'] == playerId)
        : true;
    final paused =
        network && authorityPlayers.any((p) => p['connected'] != true);
    final rankedMatch = events.matchType == 'ranked';
    final ownPlayer = players.where((p) => p['id'] == playerId).firstOrNull;
    final ownRoundComplete = rankedMatch && ownPlayer?['roundComplete'] == true;
    final betweenRounds = rankedMatch && events.phase == 'roundFinished';
    final cards = targetFrame!.cards;
    final matched = events.matched;
    final error = widget.online?.error ?? widget.bluetooth?.error;
    final code = s?['code']?.toString() ?? widget.online?.code;
    final vote = (s?['rematch'] as List? ?? []).contains(playerId);
    final authorityMatchesDisplayedRound =
        s?['roundId'] == events.roundId &&
        s?['roundIndex'] == events.roundIndex &&
        s?['phase'] == 'roundFinished';
    String result = tr(context, 'Partita completata');
    if (finished && network) {
      result = events.finishReason == 'cancelled'
          ? tr(context, 'Partita annullata')
          : events.winnerId == null
          ? tr(context, 'Pareggio')
          : events.winnerId == playerId
          ? tr(context, 'Hai vinto!')
          : tr(context, 'Hai perso');
    }
    if (finished && local?.twoPlayers == true) {
      result = events.scores[0] == events.scores[1]
          ? tr(context, 'Pareggio')
          : tr(context, 'Vince Giocatore {number}!', {
              'number': events.scores[0] > events.scores[1] ? 1 : 2,
            });
    }
    final turnStatus = network
        ? paused
              ? tr(context, 'In attesa della riconnessione…')
              : rankedMatch && ownRoundComplete
              ? tr(context, 'Attesa avversario')
              : rankedMatch
              ? tr(context, 'Completa le 12 coppie')
              : events.turn == playerId
              ? tr(context, 'Il tuo turno')
              : tr(context, 'Turno di {name}', {
                  'name':
                      players
                          .where((p) => p['id'] == events.turn)
                          .firstOrNull?['name'] ??
                      tr(context, 'un amico'),
                })
        : widget.mode == PlayMode.local
        ? tr(context, 'Turno del Giocatore {number}', {
            'number': (events.turn as int) + 1,
          })
        : tr(context, '{found} / {total} coppie', {
            'found': matched.length ~/ 2,
            'total': widget.pairs,
          });
    final status = rankedMatch
        ? betweenRounds
              ? tr(context, 'Round {round} completato', {
                  'round': events.roundIndex,
                })
              : finished
              ? events.finishReason == 'completed'
                    ? tr(context, 'Risultato dei tre round')
                    : tr(context, 'Partita interrotta')
              : tr(context, 'Round {round} di {total} · {status}', {
                  'round': events.roundIndex,
                  'total': events.roundCount,
                  'status': turnStatus,
                })
        : turnStatus;
    Future<void> copyInvite() async {
      await Clipboard.setData(
        ClipboardData(text: inviteUriForRoom(code!).toString()),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr(context, 'Invito copiato'))));
      }
    }

    final scores = Row(
      children: [
        if (local != null && widget.mode == PlayMode.solo) ...[
          Expanded(
            child: StatBox(
              label: tr(context, 'COPPIE'),
              value: '${matched.length ~/ 2} / ${widget.pairs}',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: StatBox(
              label: tr(context, 'TENTATIVI'),
              value: '${events.moves}',
            ),
          ),
        ] else if (local != null) ...[
          for (var p = 0; p < 2; p++) ...[
            if (p > 0) const SizedBox(width: 8),
            Expanded(
              child: StatBox(
                label: tr(context, 'GIOCATORE {number}', {'number': p + 1}),
                value: '${events.scores[p]}',
                active: !finished && events.turn == p,
              ),
            ),
          ],
        ] else ...[
          for (var p = 0; p < players.length; p++) ...[
            if (p > 0) const SizedBox(width: 8),
            Expanded(
              child: StatBox(
                label:
                    '${players[p]['name']}${players[p]['id'] == playerId ? tr(context, ' · TU') : ''}',
                value: rankedMatch
                    ? '${(events.totalAttempts[players[p]['id']] as num?)?.toInt() ?? ((players[p]['attempts'] as num?)?.toInt() ?? 0)}'
                    : '${players[p]['score']}',
                detail: rankedMatch
                    ? '${players[p]['score']} ${players[p]['score'] == 1 ? tr(context, 'coppia') : tr(context, 'coppie')} · ${players[p]['attempts'] ?? 0} ${(players[p]['attempts'] ?? 0) == 1 ? tr(context, 'tentativo') : tr(context, 'tentativi')}'
                    : null,
                active: !finished && players[p]['id'] == events.turn,
              ),
            ),
          ],
        ],
      ],
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) exit();
      },
      child: GameWorld(
        collection: gameTheme,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: exit,
                            tooltip: tr(context, 'Torna alla home'),
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              color: ink,
                            ),
                          ),
                          Container(
                            width: 32,
                            height: 32,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: popYellow,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: ink, width: 2),
                            ),
                            child: widget.online?.roomPreview != null
                                ? const Icon(
                                    Icons.people_alt_rounded,
                                    color: ink,
                                  )
                                : _CollectionSymbol(
                                    theme: gameTheme,
                                    value: 0,
                                    size: 26,
                                  ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.online?.roomPreview != null
                                  ? tr(context, 'Stanza {code}', {
                                      'code': widget.online!.roomPreview!.code,
                                    })
                                  : tr(context, deckNames[gameTheme]!),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: paper,
                              ),
                            ),
                          ),
                          if (!network)
                            Text(
                              clockText(local!.seconds),
                              style: const TextStyle(
                                color: paper,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          if (network)
                            Icon(
                              widget.mode == PlayMode.bluetooth
                                  ? Icons.bluetooth_rounded
                                  : Icons.public_rounded,
                              color: connected ? popYellow : coral,
                              size: 20,
                            ),
                          if (lobbyVoice != null)
                            LobbyVoiceControls(
                              voice: lobbyVoice!,
                              compact: true,
                            ),
                          if (code != null && widget.online != null)
                            IconButton(
                              tooltip: tr(context, 'Copia invito · {code}', {
                                'code': code,
                              }),
                              onPressed: copyInvite,
                              icon: const Icon(
                                Icons.ios_share_rounded,
                                color: ink,
                                size: 20,
                              ),
                            ),
                        ],
                      ),
                      if (!waiting && (error != null || !connected && network))
                        _WorldNotice(
                          message:
                              error ??
                              widget.online?.status ??
                              widget.bluetooth?.status ??
                              tr(context, 'Connessione…'),
                          error: error != null,
                          action: widget.online?.canRetry == true
                              ? IconButton(
                                  tooltip: tr(context, 'Riprova connessione'),
                                  onPressed: () => widget.online!.open(null),
                                  icon: const Icon(Icons.refresh_rounded),
                                )
                              : null,
                        ),
                      if (waiting)
                        Expanded(
                          child: _RoomStatusPanel(
                            online: widget.online,
                            error: error,
                            waitingForPlayer: s != null,
                            bluetooth: widget.mode == PlayMode.bluetooth,
                            code: code,
                            onBack: exit,
                            onLeaveLobby: exitLobby,
                            onCopy: code != null ? copyInvite : null,
                            voice: lobbyVoice,
                          ),
                        ),
                      if (!waiting) ...[
                        const SizedBox(height: 4),
                        scores,
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: popYellow,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: ink, width: 2),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 2,
                              ),
                              child: Text(
                                finished
                                    ? tr(context, 'Partita terminata')
                                    : status,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: ink,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              KeyedSubtree(
                                key: ValueKey('board-$presentationGeneration'),
                                child: _FittedBoard(
                                  count: cards.length,
                                  itemBuilder: (i) => MemoryCard(
                                    key: ValueKey('card-$i'),
                                    index: i,
                                    value: cards[i],
                                    theme: gameTheme,
                                    matched: matched.contains(i),
                                    onTurningChanged: (turning) =>
                                        cardTurningChanged(
                                          i,
                                          turning,
                                          generation,
                                        ),
                                    onConcealingChanged: (closing) =>
                                        cardConcealingChanged(
                                          i,
                                          closing,
                                          generation,
                                        ),
                                    onTap:
                                        finished ||
                                            ownRoundComplete ||
                                            boardLocked ||
                                            matched.contains(i) ||
                                            cards[i] != null ||
                                            network &&
                                                (!active ||
                                                    !connected ||
                                                    paused ||
                                                    s?['lockedUntil'] != null)
                                        ? null
                                        : () => flip(i, generation: generation),
                                  ),
                                ),
                              ),
                              if (finished)
                                SingleChildScrollView(
                                  padding: const EdgeInsets.all(12),
                                  child: Center(
                                    child: Container(
                                      constraints: const BoxConstraints(
                                        maxWidth: 380,
                                      ),
                                      padding: const EdgeInsets.all(18),
                                      decoration: BoxDecoration(
                                        color: paper,
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: ink,
                                          width: 3,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: ink,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.stars_rounded,
                                                color: coral,
                                                size: 32,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  result,
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                    fontSize: 23,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            events.finishReason == 'cancelled'
                                                ? tr(
                                                    context,
                                                    'Nessuna variazione di corone.',
                                                  )
                                                : events.finishReason ==
                                                      'forfeit'
                                                ? events.winnerId == playerId
                                                      ? tr(
                                                          context,
                                                          'Vittoria per abbandono dell’avversario.',
                                                        )
                                                      : tr(
                                                          context,
                                                          'Sconfitta per abbandono.',
                                                        )
                                                : rankedMatch
                                                ? tr(
                                                    context,
                                                    'Tentativi totali: {attempts} · {count} round',
                                                    {
                                                      'attempts': players
                                                          .map(
                                                            (player) =>
                                                                (events.totalAttempts[player['id']]
                                                                        as num?)
                                                                    ?.toInt() ??
                                                                0,
                                                          )
                                                          .join(' – '),
                                                      'count': events
                                                          .roundResults
                                                          .length,
                                                    },
                                                  )
                                                : local != null
                                                ? tr(
                                                    context,
                                                    '{time} · {count} tentativi',
                                                    {
                                                      'time': clockText(
                                                        local!.seconds,
                                                      ),
                                                      'count': events.moves,
                                                    },
                                                  )
                                                : tr(
                                                    context,
                                                    'Partita completata.',
                                                  ),
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: muted,
                                            ),
                                          ),
                                          if (rankedMatch)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 8,
                                              ),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  for (final round
                                                      in events.roundResults)
                                                    Text(
                                                      tr(
                                                        context,
                                                        'Round {round} · {deck} · {attempts} tentativi',
                                                        {
                                                          'round':
                                                              round['round'] ??
                                                              '',
                                                          'deck': tr(
                                                            context,
                                                            deckNames[round['theme']] ??
                                                                round['theme']
                                                                    .toString(),
                                                          ),
                                                          'attempts': players
                                                              .map(
                                                                (player) =>
                                                                    (round['attempts']
                                                                        as Map?)?[player['id']] ??
                                                                    0,
                                                              )
                                                              .join(' – '),
                                                        },
                                                      ),
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: muted,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          if (rewardMessage != null)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 8,
                                              ),
                                              child: Text(
                                                _gameMessage(
                                                  context,
                                                  rewardMessage!,
                                                ),
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  color: ink,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          const SizedBox(height: 12),
                                          FilledButton.icon(
                                            onPressed:
                                                replayStarting ||
                                                    vote ||
                                                    network &&
                                                        players.any(
                                                          (p) =>
                                                              p['connected'] !=
                                                              true,
                                                        )
                                                ? null
                                                : replay,
                                            icon: const Icon(
                                              Icons.replay_rounded,
                                            ),
                                            label: Text(
                                              vote
                                                  ? tr(context, 'In attesa…')
                                                  : tr(
                                                      context,
                                                      'Un’altra partita',
                                                    ),
                                            ),
                                          ),
                                          if (network &&
                                              (s?['rematch'] as List? ?? [])
                                                  .isNotEmpty &&
                                              !vote)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 8,
                                              ),
                                              child: Text(
                                                tr(
                                                  context,
                                                  'Rivincita richiesta',
                                                ),
                                                style: TextStyle(color: teal),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              if (betweenRounds)
                                SingleChildScrollView(
                                  padding: const EdgeInsets.all(12),
                                  child: Center(
                                    child: Container(
                                      constraints: const BoxConstraints(
                                        maxWidth: 420,
                                      ),
                                      margin: const EdgeInsets.all(12),
                                      padding: const EdgeInsets.all(18),
                                      decoration: BoxDecoration(
                                        color: paper,
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: ink,
                                          width: 3,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: ink,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            tr(
                                              context,
                                              'Round {round} completato',
                                              {'round': events.roundIndex},
                                            ),
                                            style: const TextStyle(
                                              fontSize: 21,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          for (final round
                                              in events.roundResults)
                                            Text(
                                              tr(
                                                context,
                                                'Round {round} · {deck} · {attempts} tentativi',
                                                {
                                                  'round': round['round'] ?? '',
                                                  'deck': tr(
                                                    context,
                                                    deckNames[round['theme']] ??
                                                        round['theme']
                                                            .toString(),
                                                  ),
                                                  'attempts': players
                                                      .map(
                                                        (player) =>
                                                            (round['attempts']
                                                                as Map?)?[player['id']] ??
                                                            0,
                                                      )
                                                      .join(' – '),
                                                },
                                              ),
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: muted,
                                              ),
                                            ),
                                          const SizedBox(height: 8),
                                          Text(
                                            tr(
                                              context,
                                              'Tentativi totali: {attempts}',
                                              {
                                                'attempts': players
                                                    .map(
                                                      (player) =>
                                                          (events.totalAttempts[player['id']]
                                                                  as num?)
                                                              ?.toInt() ??
                                                          0,
                                                    )
                                                    .join(' – '),
                                              },
                                            ),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          FilledButton.icon(
                                            onPressed:
                                                authorityMatchesDisplayedRound &&
                                                    connected &&
                                                    authorityPlayers.every(
                                                      (p) =>
                                                          p['connected'] ==
                                                          true,
                                                    ) &&
                                                    !events.roundReady.contains(
                                                      playerId,
                                                    )
                                                ? () =>
                                                      widget.online?.nextRound()
                                                : null,
                                            icon: const Icon(
                                              Icons.skip_next_rounded,
                                            ),
                                            label: Text(
                                              events.roundReady.contains(
                                                    playerId,
                                                  )
                                                  ? tr(context, 'In attesa…')
                                                  : tr(
                                                      context,
                                                      'Prossimo round',
                                                    ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fits every card inside the remaining viewport; the board has no scroll axis.
class _FittedBoard extends StatelessWidget {
  const _FittedBoard({required this.count, required this.itemBuilder});
  final int count;
  final Widget Function(int) itemBuilder;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      if (count == 0) return const SizedBox.shrink();
      const gap = 6.0;
      var columns = 2;
      var cardWidth = 0.0;
      var cardHeight = 0.0;
      var area = 0.0;
      for (var n = 2; n <= math.min(count, 12); n++) {
        if (count % n != 0) continue;
        final rows = count ~/ n;
        final w = math.min(120.0, (c.maxWidth - gap * (n - 1)) / n);
        final h = math.min(138.0, (c.maxHeight - gap * (rows - 1)) / rows);
        final fitWidth = math.min(w, h * .9);
        final fitHeight = math.min(h, w / .9);
        final candidate = fitWidth * fitHeight;
        if (candidate > area) {
          area = candidate;
          columns = n;
          cardWidth = fitWidth;
          cardHeight = fitHeight;
        }
      }
      final rows = count ~/ columns;
      return Center(
        child: SizedBox(
          width: columns * cardWidth + (columns - 1) * gap,
          height: rows * cardHeight + (rows - 1) * gap,
          child: Column(
            children: [
              for (var row = 0; row < rows; row++) ...[
                if (row > 0) const SizedBox(height: gap),
                Row(
                  children: [
                    for (var column = 0; column < columns; column++) ...[
                      if (column > 0) const SizedBox(width: gap),
                      SizedBox(
                        width: cardWidth,
                        height: cardHeight,
                        child: itemBuilder(row * columns + column),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class StatBox extends StatelessWidget {
  const StatBox({
    super.key,
    required this.label,
    required this.value,
    this.active = false,
    this.detail,
  });
  final String label, value;
  final bool active;
  final String? detail;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: active ? popYellow : paper,
      border: Border.all(color: ink, width: 2),
      borderRadius: BorderRadius.circular(14),
      boxShadow: const [BoxShadow(color: ink, offset: Offset(0, 3))],
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (detail != null)
                Text(
                  detail!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: muted),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class BluetoothLobby extends StatefulWidget {
  const BluetoothLobby.create({
    super.key,
    required this.prefs,
    required this.name,
    required int this.pairs,
    required String this.theme,
    this.economy,
    this.gameKey,
  }) : hosting = true;

  const BluetoothLobby.search({
    super.key,
    required this.prefs,
    required this.name,
    this.economy,
    this.gameKey,
  }) : hosting = false,
       pairs = null,
       theme = null;

  final SharedPreferences prefs;
  final EconomyController? economy;
  final GlobalKey? gameKey;
  final bool hosting;
  final String name;
  final String? theme;
  final int? pairs;
  @override
  State<BluetoothLobby> createState() => _BluetoothLobbyState();
}

class _BluetoothLobbyState extends State<BluetoothLobby> {
  late final BluetoothController ble;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    ble = BluetoothController(
      ticketProvider: (pairs, theme) =>
          widget.economy?.takeTicket(
            mode: 'bluetooth',
            pairs: pairs,
            theme: theme,
          ) ??
          Future.value(null),
    );
    ble.addListener(update);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.hosting) {
        unawaited(connect());
      } else {
        unawaited(scan());
      }
    });
  }

  void update() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ble.removeListener(update);
    ble.dispose();
    super.dispose();
  }

  Future<void> scan() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await ble.scan();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> connect({BluetoothPeer? peer}) async {
    if (busy || (peer == null && !widget.hosting)) return;
    setState(() => busy = true);
    try {
      if (peer == null) {
        await ble.host(widget.name, widget.pairs!, widget.theme!);
      } else {
        await ble.join(peer, widget.name);
      }
      if (!mounted || ble.error != null) return;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => GameScreen(
            key: widget.gameKey,
            prefs: widget.prefs,
            pairs: ble.state?['pairs'] as int? ?? widget.pairs ?? 8,
            theme: ble.state?['theme'] as String? ?? widget.theme ?? 'garden',
            mode: PlayMode.bluetooth,
            bluetooth: ble,
            economy: widget.economy,
          ),
        ),
      );
      await ble.leave();
      if (mounted && widget.hosting) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                context,
                'Bluetooth non disponibile. Controlla permessi e connessione.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => GameWorld(
    collection: widget.theme ?? 'garden',
    child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: paper,
        iconTheme: const IconThemeData(color: ink),
        actionsIconTheme: const IconThemeData(color: ink),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.hosting
              ? tr(context, 'Crea partita')
              : tr(context, 'Cerca partita'),
        ),
        actions: [
          IconButton(
            tooltip: tr(context, 'Aiuto Bluetooth'),
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(tr(context, 'Connessione Bluetooth')),
                content: Text(
                  tr(
                    context,
                    'Attiva il Bluetooth e tieni le due app aperte. Un giocatore ospita, l’altro cerca.\n\nSe la partita non compare, scambiate i ruoli: alcuni Android non possono ospitare. Sui modelli meno recenti può servire il permesso di posizione.',
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(tr(context, 'Chiudi')),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                children: [
                  Text(
                    widget.hosting
                        ? tr(context, '{deck} · {count} coppie', {
                            'deck': tr(context, deckNames[widget.theme] ?? ''),
                            'count': widget.pairs ?? 0,
                          })
                        : tr(
                            context,
                            'Scegli una partita vicina. Il mazzo e le coppie sono quelli di chi crea.',
                          ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: paper),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: widget.hosting
                        ? FilledButton.icon(
                            onPressed: busy ? null : () => connect(),
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text(
                              busy
                                  ? tr(context, 'Creazione in corso…')
                                  : tr(context, 'Riprova'),
                            ),
                          )
                        : OutlinedButton.icon(
                            onPressed: busy ? null : scan,
                            icon: const Icon(Icons.radar_rounded),
                            label: Text(tr(context, 'Aggiorna ricerca')),
                          ),
                  ),
                  const SizedBox(height: 8),
                  _WorldNotice(
                    message: ble.error ?? ble.status,
                    error: ble.error != null,
                    action: busy || ble.scanning
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 8),
                  if (!widget.hosting)
                    Expanded(
                      child: _NearbyPeers(
                        peers: ble.peers,
                        onJoin: busy ? null : (peer) => connect(peer: peer),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _NearbyPeers extends StatefulWidget {
  const _NearbyPeers({required this.peers, required this.onJoin});
  final List<BluetoothPeer> peers;
  final void Function(BluetoothPeer)? onJoin;
  @override
  State<_NearbyPeers> createState() => _NearbyPeersState();
}

class _NearbyPeersState extends State<_NearbyPeers> {
  int page = 0;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      if (widget.peers.isEmpty) {
        return Center(
          child: _WorldNotice(message: tr(context, 'Nessuna partita trovata')),
        );
      }
      final perPage = math.max(1, ((c.maxHeight - 48) / 64).floor());
      final pages = (widget.peers.length / perPage).ceil();
      final current = math.min(page, pages - 1);
      final peers = widget.peers.skip(current * perPage).take(perPage);
      return Column(
        children: [
          Expanded(
            child: Column(
              children: [
                for (final peer in peers)
                  SizedBox(
                    height: 64,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Material(
                        color: paper,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: ink, width: 1.5),
                        ),
                        child: ListTile(
                          leading: const Icon(
                            Icons.smartphone_rounded,
                            color: teal,
                          ),
                          title: Text(
                            peer.name == 'SommoMemory vicino'
                                ? tr(context, peer.name)
                                : peer.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_rounded,
                            color: ink,
                          ),
                          onTap: widget.onJoin == null
                              ? null
                              : () => widget.onJoin!(peer),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (pages > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: tr(context, 'Precedenti'),
                  onPressed: current == 0
                      ? null
                      : () => setState(() => page = current - 1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Text(
                  '${current + 1} / $pages',
                  style: const TextStyle(color: paper),
                ),
                IconButton(
                  tooltip: tr(context, 'Successive'),
                  onPressed: current + 1 == pages
                      ? null
                      : () => setState(() => page = current + 1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
        ],
      );
    },
  );
}

/// A fixed, opaque surface keeps status readable over every collection world.
class _WorldNotice extends StatelessWidget {
  const _WorldNotice({required this.message, this.error = false, this.action});
  final String message;
  final bool error;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Material(
    color: error ? const Color(0xFFFFE8DF) : paper,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            error ? Icons.error_outline_rounded : Icons.info_outline_rounded,
            color: ink,
            size: 19,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _gameMessage(context, message),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: ink, fontSize: 13),
            ),
          ),
          ?action,
        ],
      ),
    ),
  );
}

class _RoomStatusPanel extends StatelessWidget {
  const _RoomStatusPanel({
    required this.online,
    required this.error,
    required this.waitingForPlayer,
    required this.bluetooth,
    required this.code,
    required this.onBack,
    required this.onLeaveLobby,
    this.onCopy,
    this.voice,
  });
  final OnlineGame? online;
  final LobbyVoice? voice;
  final String? error, code;
  final bool waitingForPlayer, bluetooth;
  final VoidCallback onBack;
  final VoidCallback onLeaveLobby;
  final VoidCallback? onCopy;
  @override
  Widget build(BuildContext context) {
    final preview = online?.roomPreview;
    final terminal = online?.terminalError == true;
    final failed = error != null;
    final reconnecting =
        waitingForPlayer && online != null && !online!.connected && !terminal;
    final update = online?.errorCode == 'UPDATE_REQUIRED';
    final state = online?.state;
    final lobby = waitingForPlayer && state?['lobbyMode'] == true;
    final lobbyPlayers = (state?['players'] as List? ?? const [])
        .whereType<Map>()
        .map((player) => Map<String, dynamic>.from(player))
        .toList();
    final lobbyReady = (state?['lobbyReady'] as List? ?? const [])
        .whereType<String>()
        .toSet();
    final lobbyHost =
        lobbyPlayers.isNotEmpty && lobbyPlayers.first['id'] == online?.playerId;
    final lobbySelfReady = lobbyReady.contains(online?.playerId);
    final lobbyBothConnected =
        lobbyPlayers.length == 2 &&
        lobbyPlayers.every((player) => player['connected'] == true);
    final title = preview != null
        ? tr(context, 'Stanza completa')
        : update
        ? tr(context, 'Aggiornamento necessario')
        : failed || terminal
        ? tr(context, 'Partita non disponibile')
        : reconnecting
        ? tr(context, 'Riconnessione…')
        : lobby
        ? tr(context, 'Lobby della stanza')
        : waitingForPlayer
        ? tr(context, 'In attesa del secondo giocatore')
        : tr(context, 'Connessione alla partita…');
    final description = preview != null
        ? tr(
            context,
            'I due posti sono occupati. Non sei entrato nella partita.',
          )
        : failed || terminal
        ? error ?? tr(context, 'Questa stanza non è più disponibile.')
        : reconnecting
        ? online!.status
        : lobby
        ? lobbyPlayers.length < 2
              ? tr(
                  context,
                  'Condividi il codice: un amico può ancora entrare nella lobby.',
                )
              : tr(
                  context,
                  'Entrambi i giocatori devono scegliere Pronto per iniziare.',
                )
        : waitingForPlayer
        ? bluetooth
              ? tr(
                  context,
                  'Sul secondo telefono scegli Bluetooth e cerca la partita.',
                )
              : tr(context, 'Condividi il codice per entrare nella stanza.')
        : online?.status ?? tr(context, 'Prepariamo la partita…');
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 330;
        final players = preview?.players ?? <Map<String, dynamic>>[];
        final winner = players
            .where((p) => p['id'] == preview?.winnerId)
            .firstOrNull?['name'];
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Material(
              color: paper,
              borderRadius: BorderRadius.circular(22),
              child: Padding(
                padding: EdgeInsets.all(compact ? 12 : 20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: ink,
                          fontSize: compact ? 20 : 23,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: compact ? 6 : 10),
                      Text(
                        _gameMessage(context, description),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: ink, fontSize: 14),
                      ),
                      if (lobby) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            for (var index = 0; index < 2; index++) ...[
                              if (index > 0) const SizedBox(width: 8),
                              Expanded(
                                child: Builder(
                                  builder: (context) {
                                    final player = lobbyPlayers.length > index
                                        ? lobbyPlayers[index]
                                        : null;
                                    final playerConnected =
                                        player?['connected'] == true;
                                    final playerId = player?['id'];
                                    final playerReady =
                                        playerId is String &&
                                        lobbyReady.contains(playerId);
                                    final role = index == 0
                                        ? 'Host'
                                        : tr(context, 'Ospite');
                                    final playerStatus = player == null
                                        ? tr(context, 'Posto libero')
                                        : !playerConnected
                                        ? tr(context, 'Disconnesso')
                                        : playerReady
                                        ? tr(context, 'Pronto')
                                        : tr(context, 'In attesa');
                                    return Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE8E2F3),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            player == null
                                                ? role
                                                : '${player['name']} · $role',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: ink,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  playerStatus,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: ink,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              if (playerId is String &&
                                                  voice?.memberFor(playerId) !=
                                                      null) ...[
                                                const SizedBox(width: 4),
                                                Icon(
                                                  voice!
                                                          .memberFor(playerId)!
                                                          .muted
                                                      ? Icons.mic_off_rounded
                                                      : Icons.mic_rounded,
                                                  size: 14,
                                                  color: ink,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed:
                              lobbyBothConnected &&
                                  online?.connected == true &&
                                  !lobbySelfReady
                              ? () => online!.ready(true)
                              : null,
                          child: Text(
                            lobbySelfReady
                                ? tr(context, 'In attesa…')
                                : tr(context, 'Pronto'),
                          ),
                        ),
                        TextButton(
                          onPressed: onLeaveLobby,
                          child: Text(
                            lobbyHost
                                ? tr(context, 'Chiudi lobby')
                                : tr(context, 'Esci dalla lobby'),
                          ),
                        ),
                        if (voice != null) ...[
                          const SizedBox(height: 4),
                          LobbyVoiceControls(voice: voice!),
                        ],
                      ],
                      if (preview != null) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            for (var i = 0; i < players.length; i++) ...[
                              if (i > 0) const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8E2F3),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${players[i]['name']}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: ink,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        '${players[i]['score']} ${players[i]['score'] == 1 ? tr(context, 'coppia') : tr(context, 'coppie')}',
                                        style: const TextStyle(
                                          color: ink,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          preview.phase == 'finished'
                              ? preview.winnerId == null
                                    ? tr(context, 'Risultato finale · Pareggio')
                                    : tr(
                                        context,
                                        'Risultato finale · Vince {name}',
                                        {
                                          'name':
                                              winner ??
                                              tr(context, 'un giocatore'),
                                        },
                                      )
                              : tr(
                                  context,
                                  'Partita in corso · Stanza {code}',
                                  {'code': preview.code},
                                ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (preview != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            tr(
                              context,
                              'Anteprima statica · aggiorna per il risultato',
                            ),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: ink, fontSize: 11),
                          ),
                        ),
                      if (update) ...[
                        const SizedBox(height: 8),
                        Text(
                          tr(
                            context,
                            'Aggiorna SommoMemory da TestFlight o Google Play, poi riapri l’invito.',
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: ink, fontSize: 13),
                        ),
                      ],
                      if (!failed &&
                          !terminal &&
                          preview == null &&
                          code != null) ...[
                        const SizedBox(height: 8),
                        SelectableText(
                          code!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: ink,
                            fontSize: 30,
                            letterSpacing: 4,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (!bluetooth && onCopy != null)
                          TextButton.icon(
                            onPressed: onCopy,
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            label: Text(tr(context, 'Copia invito')),
                          ),
                      ],
                      if (failed || terminal || preview != null) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(48, 44),
                                ),
                                onPressed: onBack,
                                child: Text(
                                  preview != null
                                      ? tr(context, 'Cambia stanza')
                                      : tr(context, 'Torna alla home'),
                                ),
                              ),
                            ),
                            if (preview != null) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                tooltip: tr(context, 'Aggiorna anteprima'),
                                onPressed: online?.canRefreshPreview == true
                                    ? () => online!.refreshPreview()
                                    : null,
                                icon: const Icon(Icons.refresh_rounded),
                              ),
                            ],
                            if (online?.canRetry == true) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () => online!.open(null),
                                tooltip: tr(context, 'Riprova connessione'),
                                icon: const Icon(Icons.refresh_rounded),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Localize display-only text while leaving network messages and stored receipts unchanged.
String _gameMessage(BuildContext context, String message) {
  final patterns = <(RegExp, String, String)>[
    (
      RegExp(r'^Visibile come SommoMemory (.+)$'),
      'Visibile come SommoMemory {code}',
      'code',
    ),
    (RegExp(r'^Connessione a (.+)…$'), 'Connessione a {name}…', 'name'),
    (RegExp(r'^\+(\d+) gemme$'), '+{count} gemme', 'count'),
    (RegExp(r'^([+-]?\d+) corone$'), '{count} corone', 'count'),
    (
      RegExp(r'^Saldo aggiornato · (\d+) gemme$'),
      'Saldo aggiornato · {count} gemme',
      'count',
    ),
  ];
  for (final (pattern, source, key) in patterns) {
    final match = pattern.firstMatch(message);
    if (match != null) return tr(context, source, {key: match.group(1)!});
  }
  // A ranked reward receipt combines crowns and the gem-balance message.
  if (RegExp(r'^[+-]?\d+ corone · ').hasMatch(message)) {
    final separator = message.indexOf(' · ');
    return '${_gameMessage(context, message.substring(0, separator))} · ${_gameMessage(context, message.substring(separator + 3))}';
  }
  return tr(context, message);
}
