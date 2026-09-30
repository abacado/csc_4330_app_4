import 'package:flutter/material.dart';

import '../core/arcade_controller.dart';
import '../core/game_definition.dart';
import '../games/game_registry.dart';
import '../theme/arcade_theme.dart';

class ArcadeHome extends StatefulWidget {
  const ArcadeHome({super.key, required this.controller});
  final ArcadeController controller;
  @override
  State<ArcadeHome> createState() => _ArcadeHomeState();
}

class _ArcadeHomeState extends State<ArcadeHome> {
  int _tab = 0;
  GameCategory? _category;
  ArcadeController get controller => widget.controller;

  void _open(String id) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => gameScreen(id, controller)));

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                      child: _header(),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 36),
                    sliver: SliverToBoxAdapter(
                      child: switch (_tab) {
                        1 => _history(),
                        2 => _profile(),
                        _ => _library(),
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (index) => setState(() => _tab = index),
          backgroundColor: arcadePanel,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.sports_esports_outlined),
              selectedIcon: Icon(Icons.sports_esports),
              label: 'Arcade',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_rounded),
              label: 'Activity',
            ),
            NavigationDestination(
              icon: Icon(Icons.face_rounded),
              label: 'Player',
            ),
          ],
        ),
      );
    },
  );

  Widget _header() => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 20,
    runSpacing: 16,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: arcadeMint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.sports_esports, color: arcadeBackground),
          ),
          const SizedBox(width: 12),
          const Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'POCKET ARCADE',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    fontSize: 17,
                  ),
                ),
                Text(
                  'GOOD GAMES. GOOD COMPANY.',
                  style: TextStyle(
                    fontSize: 9,
                    color: arcadeMuted,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      Chip(
        avatar: Icon(
          controller.status == CloudStatus.connected
              ? Icons.cloud_done_outlined
              : Icons.person_outline,
          size: 17,
          color: arcadeMint,
        ),
        label: Text(controller.name),
      ),
    ],
  );

  Widget _library() {
    final visible = games
        .where((game) => _category == null || game.category == _category)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [Color(0xFF272749), Color(0xFF163C3A)],
            ),
            border: Border.all(color: arcadeMint.withValues(alpha: .3)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) => Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PRESS PAUSE ON THE EVERYDAY',
                        style: TextStyle(
                          color: arcadeMint,
                          letterSpacing: 2,
                          fontSize: 11,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Small games.\nBig play energy.',
                        style: TextStyle(
                          fontSize: constraints.maxWidth < 480 ? 30 : 44,
                          fontWeight: FontWeight.w900,
                          height: 1.12,
                          letterSpacing: -1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Your favorite classics, all in one little arcade.\nNo coins. Just one more round.',
                        style: TextStyle(color: arcadeMuted, height: 1.6),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () => _open('tic_tac_toe'),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Play Tic-Tac-Toe'),
                      ),
                    ],
                  ),
                ),
                if (constraints.maxWidth > 680)
                  const Padding(
                    padding: EdgeInsets.only(left: 32),
                    child: _ArcadeArt(),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 30),
        Wrap(
          spacing: 16,
          runSpacing: 14,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              'CHOOSE YOUR CHALLENGE',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.4),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All games'),
                  selected: _category == null,
                  onSelected: (_) => setState(() => _category = null),
                ),
                ChoiceChip(
                  label: const Text('Strategy'),
                  selected: _category == GameCategory.strategy,
                  onSelected: (_) =>
                      setState(() => _category = GameCategory.strategy),
                ),
                ChoiceChip(
                  label: const Text('Puzzles'),
                  selected: _category == GameCategory.puzzles,
                  onSelected: (_) =>
                      setState(() => _category = GameCategory.puzzles),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900
                ? 3
                : constraints.maxWidth >= 580
                ? 2
                : 1;
            final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: visible
                  .map(
                    (game) => SizedBox(
                      width: width,
                      child: _GameCard(game: game, onTap: () => _open(game.id)),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 24),
        Text(
          '${games.where((game) => game.ready).length} ready to play • ${games.where((game) => !game.ready).length} on the way',
          style: const TextStyle(color: arcadeMuted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _history() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Your play journal',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 12),
      const Text(
        'A little record of your latest rounds. The last 100 results stay with this guest.',
        style: TextStyle(color: arcadeMuted, height: 1.6),
      ),
      const SizedBox(height: 20),
      _connection(),
      const SizedBox(height: 20),
      if (controller.results.isEmpty)
        _panel(
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.flag_outlined, color: arcadeMint, size: 36),
              SizedBox(height: 16),
              Text('Your next round starts the story.'),
              SizedBox(height: 8),
              Text(
                'Finish a game to see it here.',
                style: TextStyle(color: arcadeMuted),
              ),
            ],
          ),
        ),
      for (final result in controller.results)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _panel(
            Row(
              children: [
                Icon(
                  games.where((g) => g.id == result.gameId).firstOrNull?.icon ??
                      Icons.sports_esports,
                  color: arcadeMint,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        games
                                .where((g) => g.id == result.gameId)
                                .firstOrNull
                                ?.name ??
                            result.gameId,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${result.mode == 'online'
                            ? 'Online'
                            : result.mode == 'solo'
                            ? 'Solo'
                            : 'Same device'} · ${_date(result.completedAt)}',
                        style: const TextStyle(
                          color: arcadeMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  result.outcome.toUpperCase(),
                  style: const TextStyle(color: arcadeMint, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
    ],
  );

  String _date(DateTime value) {
    final date = value.toLocal();
    return '${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _profile() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Hey, ${controller.name}.',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 12),
      const Text(
        'No passwords. No long sign-up. Just play.',
        style: TextStyle(color: arcadeMuted, height: 1.6),
      ),
      const SizedBox(height: 24),
      _panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'YOUR PLAYER TAG',
              style: TextStyle(
                color: arcadeMint,
                letterSpacing: 2,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              controller.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _rename,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Change name'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _connection(),
      const SizedBox(height: 20),
      const Text(
        'Your guest belongs to this browser or device. Clearing app data creates a new guest; old cloud results cannot be recovered without an account.',
        style: TextStyle(color: arcadeMuted, height: 1.6),
      ),
    ],
  );

  Widget _connection() => _panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          switch (controller.status) {
            CloudStatus.connected => 'CLOUD CONNECTED',
            CloudStatus.connecting => 'CONNECTING…',
            CloudStatus.unavailable => 'LOCAL PLAY AVAILABLE',
            CloudStatus.local => 'PLAYING ON THIS DEVICE',
          },
          style: const TextStyle(
            color: arcadeMint,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          controller.notice ??
              (controller.status == CloudStatus.connected
                  ? 'Results sync to your guest profile. Online rooms are ready.'
                  : controller.status == CloudStatus.connecting
                  ? 'Getting your guest profile ready.'
                  : 'Local games and activity work now. Online play will unlock when the arcade is connected.'),
          style: const TextStyle(color: arcadeMuted, height: 1.6),
        ),
        if (controller.cloud != null &&
            controller.status != CloudStatus.connecting) ...[
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: controller.status == CloudStatus.connected
                ? controller.refreshHistory
                : controller.connect,
            icon: const Icon(Icons.sync),
            label: Text(
              controller.status == CloudStatus.connected
                  ? 'Sync results'
                  : 'Reconnect',
            ),
          ),
        ],
      ],
    ),
  );

  Widget _panel(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: arcadePanel,
      borderRadius: BorderRadius.circular(18),
    ),
    child: child,
  );

  Future<void> _rename() async {
    final value = await showDialog<String>(
      context: context,
      builder: (context) => _RenameDialog(initialName: controller.name),
    );
    if (value != null) {
      try {
        await controller.rename(value);
      } on Object {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not save your name. Try again.'),
            ),
          );
        }
      }
    }
  }
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initialName});
  final String initialName;
  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _input = TextEditingController(text: widget.initialName);
  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _save() {
    if (_input.text.trim().isNotEmpty) {
      Navigator.pop(context, _input.text);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Make it yours'),
    content: TextField(
      controller: _input,
      maxLength: 20,
      autofocus: true,
      decoration: const InputDecoration(labelText: 'Player name'),
      onSubmitted: (_) => _save(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _save, child: const Text('Save')),
    ],
  );
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.game, required this.onTap});
  final GameDefinition game;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: arcadePanel,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: game.color.withValues(alpha: .25)),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: game.color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(game.icon, color: game.color, size: 30),
                ),
                const Spacer(),
                Text(
                  game.ready ? 'READY TO PLAY' : 'COMING SOON',
                  style: TextStyle(
                    color: game.ready ? arcadeMint : arcadeMuted,
                    fontSize: 10,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              game.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
            ),
            const SizedBox(height: 8),
            Text(
              game.tagline,
              style: const TextStyle(color: arcadeMuted, height: 1.5),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Text(
                  game.players,
                  style: TextStyle(color: game.color, fontSize: 12),
                ),
                const Spacer(),
                Icon(Icons.arrow_forward_rounded, color: game.color, size: 20),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _ArcadeArt extends StatelessWidget {
  const _ArcadeArt();
  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: -.08,
    child: Container(
      width: 240,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: arcadeBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: arcadeMint, width: 3),
        boxShadow: [
          BoxShadow(
            color: arcadeMint.withValues(alpha: .15),
            blurRadius: 30,
            offset: const Offset(8, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'ONE MORE ROUND',
            style: TextStyle(color: arcadeMint, fontSize: 12, letterSpacing: 2),
          ),
          const SizedBox(height: 18),
          ExcludeSemantics(
            child: GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 7,
              crossAxisSpacing: 7,
              children: List.generate(
                9,
                (index) => Container(
                  decoration: BoxDecoration(
                    color: arcadePanel,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      ['X', '', 'O', '', 'X', '', 'O', '', 'X'][index],
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: index.isEven ? arcadeMint : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.circle, size: 10, color: Color(0xFFFF819C)),
              SizedBox(width: 8),
              Icon(Icons.circle, size: 10, color: Color(0xFFFFCA75)),
              SizedBox(width: 8),
              Icon(Icons.circle, size: 10, color: arcadeMint),
            ],
          ),
        ],
      ),
    ),
  );
}
