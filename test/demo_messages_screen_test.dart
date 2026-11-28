import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:una/una.dart';
import 'package:una_demo/data/messages_data.dart';
import 'package:una_demo/screens/messages_screen.dart';
import 'package:una_demo/teal_color_scheme.dart';
import 'package:una_demo/widgets/messages_assistant.dart';
import 'package:una_demo/widgets/messages_composer.dart';
import 'package:una_demo/widgets/messages_conversation.dart';
import 'package:una_demo/widgets/messages_conversation_list.dart';
import 'package:una_demo/widgets/messages_details_pane.dart';

import 'demo_support.dart';

/// The Messages screen on its own, under an app bar as the Demo shell
/// gives it. Not pumped through `App`: the other screens are not this
/// test's business.
///
/// Nobody answers unless a test gives [replies]: what is sent stays the
/// newest message.
Future<void> pumpMessages(
  WidgetTester tester, {
  required Size size,
  Brightness brightness = Brightness.light,
  MessagesReplies replies = const MessagesReplies.none(),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    // The conversations are the session's, so the screen needs one; this
    // one answers the way the test asked.
    DemoSessionHost(
      replies: replies,
      child: UnaApp(
        theme: ThemeData(colorScheme: TealColorScheme.of(brightness)),
        home: const Scaffold(
          appBar: AppBar(title: Text('demo')),
          body: MessagesScreen(),
        ),
      ),
    ),
  );
  await settle(tester);
}

/// Pumps fixed frames: the typing indicator never settles.
Future<void> settle(WidgetTester tester, {int frames = 12}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

const desktop = Size(1440, 1000);
const laptop = Size(1024, 800);
const tablet = Size(768, 900);
const phone = Size(390, 844);

Finder inList(Finder finder) => find.descendant(
  of: find.byType(MessagesConversationList),
  matching: finder,
);

Finder inConversation(Finder finder) => find.descendant(
  of: find.byType(MessagesConversationView),
  matching: finder,
);

/// A message of the open thread, wherever it is: the thread is a lazy list,
/// and what is scrolled out of view above is built but off stage.
Finder inThread(String text) => find.descendant(
  of: find.byType(MessagesConversationView),
  matching: find.widgetWithText(ChatBubble, text, skipOffstage: false),
  skipOffstage: false,
);

Finder inDetails(Finder finder) =>
    find.descendant(of: find.byType(MessagesDetailsPane), matching: finder);

final composerField = find.descendant(
  of: find.byType(MessagesComposer),
  matching: find.byType(EditableText),
);

final sendButton = find.byIcon(PhosphorIconsRegular.paperPlaneTilt);

Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await settle(tester);
}

/// Taps a filter chip. The chips scroll sideways when they do not fit, and
/// the test font is wide enough that the last ones never do.
Future<void> tapChip(WidgetTester tester, String label) async {
  final chip = find.widgetWithText(Chip, label);
  await tester.ensureVisible(chip);
  await settle(tester, frames: 2);
  await tapAndSettle(tester, chip);
}

void main() {
  group('builds without overflowing', () {
    for (final size in [desktop, laptop, tablet, phone]) {
      for (final brightness in Brightness.values) {
        testWidgets('${size.width.toInt()}x${size.height.toInt()} '
            '${brightness.name}', (tester) async {
          await pumpMessages(tester, size: size, brightness: brightness);

          expect(tester.takeException(), isNull);
          expect(find.byType(MessagesConversationList), findsOneWidget);
          expect(inList(find.text('Messages')), findsOneWidget);
        });
      }
    }

    testWidgets('a conversation page on a phone, light and dark', (
      tester,
    ) async {
      for (final brightness in Brightness.values) {
        await pumpMessages(tester, size: phone, brightness: brightness);
        await tapAndSettle(tester, find.text('Omar Rahimi'));

        expect(tester.takeException(), isNull);
        expect(find.byType(MessagesConversationPage), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('every conversation opens in the desktop card', (tester) async {
      await pumpMessages(tester, size: desktop);
      // Requests are behind their chip; open those from there.
      for (final conversation in MessagesData.conversations) {
        if (conversation.request) continue;
        await tapAndSettle(tester, inList(find.text(conversation.name)));
        expect(tester.takeException(), isNull, reason: conversation.name);
      }
      await tapChip(tester, 'Requests · 2');
      for (final conversation in MessagesData.conversations) {
        if (!conversation.request) continue;
        await tapAndSettle(tester, inList(find.text(conversation.name)));
        expect(tester.takeException(), isNull, reason: conversation.name);
      }
    });

    testWidgets('the card scrolls rather than shrinking below its minimum', (
      tester,
    ) async {
      await pumpMessages(tester, size: const Size(1440, 480));

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(Card)).height,
        MessagesScreen.minHeight,
      );
    });
  });

  group('on a desktop', () {
    testWidgets('the card has the design\'s three panes', (tester) async {
      await pumpMessages(tester, size: desktop);

      expect(find.byType(MessagesConversationPane), findsOneWidget);
      expect(find.byType(MessagesDetailsPane), findsOneWidget);

      // One card, as tall as the window allows: the app bar, its hairline
      // and the page margins around it.
      final card = tester.getRect(find.byType(Card));
      expect(card.top, 64 + 1 + 24);
      expect(card.bottom, desktop.height - 24);
      expect(card.width, 1232);

      // Pane widths from the design: 360, the rest, 340 (300 and its
      // padding), with a hairline between each.
      expect(
        tester.getSize(find.byType(MessagesConversationList)).width,
        MessagesScreen.listWidth,
      );
      expect(
        tester.getSize(find.byType(MessagesDetailsPane)).width,
        MessagesScreen.detailsWidth,
      );
      expect(
        tester.getSize(find.byType(MessagesConversationPane)).width,
        1232 - 2 - 360 - 340 - 2,
      );
    });

    testWidgets('the list shows the design\'s rows', (tester) async {
      await pumpMessages(tester, size: desktop);

      expect(find.text('Search messages'), findsOneWidget);
      for (final chip in ['Focused', 'Unread', 'Requests · 2', 'Groups']) {
        expect(
          find.widgetWithText(Chip, chip),
          findsOneWidget,
          reason: chip,
        );
      }
      expect(
        tester.widget<Chip>(find.widgetWithText(Chip, 'Focused')).selected,
        isTrue,
      );

      const rows = {
        // Pinned above the conversations.
        'Una Assistant': (
          '1m',
          'Ask me to draft a post, tighten a message or prepare for a call.',
        ),
        'Omar Rahimi': ('2m', 'You: Sending the deck now. Slides 12 to 18…'),
        'Sara Lindqvist': ('18m', 'Can we move the research sync to Thursday?'),
        'Design Systems Guild': (
          '1h',
          'Freya: Tokens v3 is live, release notes in thread',
        ),
        'Claire Dubois': (
          '3h',
          'Thanks Noor, I’ve shared your portfolio with the team.',
        ),
        'Julian Reyes': ('Mon', 'See you at Config! Lounge after my talk?'),
        'Aisha Rahman': ('Sun', 'Sharing the interview guide here'),
        'Mateo Alvarez': ('Nov 14', 'Ha, yes. That bug again.'),
        'Mei Tanaka': ('Nov 12', 'Love the new brand work!'),
      };
      expect(inList(find.byType(ListTile)), findsNWidgets(rows.length));
      for (final MapEntry(key: name, value: (time, preview)) in rows.entries) {
        final row = find.ancestor(
          of: inList(find.text(name)),
          matching: find.byType(ListTile),
        );
        expect(row, findsOneWidget, reason: name);
        expect(
          find.descendant(of: row, matching: find.text(time)),
          findsOneWidget,
          reason: name,
        );
        expect(
          find.descendant(of: row, matching: find.text(preview)),
          findsOneWidget,
          reason: name,
        );
      }

      // Omar's row is the selected one; the unread rows carry their counts.
      ListTile tile(String name) => tester.widget(
        find.ancestor(
          of: inList(find.text(name)),
          matching: find.byType(ListTile),
        ),
      );
      expect(tile('Omar Rahimi').selected, isTrue);
      expect(tile('Sara Lindqvist').selected, isFalse);
      expect(inList(find.widgetWithText(IndicatorBadge, '1')), findsOneWidget);
      expect(inList(find.widgetWithText(IndicatorBadge, '4')), findsOneWidget);
    });

    testWidgets('the conversation shows Omar\'s thread verbatim', (
      tester,
    ) async {
      await pumpMessages(tester, size: desktop);

      final header = find.byType(MessagesConversationPane);
      expect(
        find.descendant(of: header, matching: find.text('Omar Rahimi')),
        findsOneWidget,
      );
      expect(
        find.text('Active now · Design lead at Birchline'),
        findsOneWidget,
      );
      for (final icon in [
        PhosphorIconsRegular.phone,
        PhosphorIconsRegular.videoCamera,
        PhosphorIconsRegular.info,
      ]) {
        expect(find.byIcon(icon), findsOneWidget);
      }

      // The thread is a lazy list that opens on its newest message: what
      // is above the fold is read after scrolling up to it.
      final scrollable = tester.state<ScrollableState>(
        inConversation(find.byType(Scrollable)).first,
      );
      const earlier = [
        'Hey Noor! Loved your talk proposal for Config Nordics. Do you have '
            'slides yet?',
        'Happy to give feedback this afternoon if that helps.',
        'Thank you! I have a rough draft. Would love a second pair of eyes '
            'before I polish it.',
      ];
      const later = [
        'Sending the deck now. Slides 12 to 18 are the ones I’m unsure about.',
        'This is how we mapped ours. Might help with slide 14.',
      ];
      for (final text in later) {
        expect(inThread(text), findsOneWidget, reason: text);
      }
      for (var i = 0; i < 3; i++) {
        scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
        await tester.pump();
      }
      expect(inConversation(find.text('Today')), findsOneWidget);
      for (final text in earlier) {
        expect(inThread(text), findsOneWidget, reason: text);
      }
      expect(
        inConversation(
          find.text('calm-by-default-draft.pdf', skipOffstage: false),
        ),
        findsOneWidget,
      );
      expect(
        inConversation(find.text('4.2 MB · 32 slides', skipOffstage: false)),
        findsOneWidget,
      );
      // Outgoing bubbles sit against the end edge, incoming ones after the
      // avatar gutter.
      final view = tester.getRect(find.byType(MessagesConversationView));
      Rect bubble(String start) => tester.getRect(
        find.descendant(
          of: inThread(start),
          matching: find.byType(DecoratedBox, skipOffstage: false),
        ),
      );
      final incoming = bubble(earlier[1]);
      final outgoing = bubble(earlier[2]);
      expect(incoming.left, view.left + 24 + 28 + 8);
      expect(outgoing.right, view.right - 24);
      // The design caps a line of outgoing text at 420, and an incoming row
      // — avatar, gutter and bubble — at the same; each bubble carries its
      // own cap.
      expect(outgoing.width, 420 + 28);
      scrollable.position.jumpTo(0);
      await settle(tester);

      expect(inConversation(find.text('Seen 10:14')), findsOneWidget);
      expect(
        find.bySemanticsLabel('Whiteboard with a mapped user flow'),
        findsOneWidget,
      );
      expect(inConversation(find.byType(TypingIndicator)), findsOneWidget);
      expect(
        inConversation(find.byIcon(PhosphorIconsFill.heart)),
        findsOneWidget,
      );

      final caps = {
        for (final bubble in tester.widgetList<ChatBubble>(
          inConversation(find.byType(ChatBubble, skipOffstage: false)),
        ))
          bubble.direction: bubble.maxWidth,
      };
      expect(caps, {
        ChatBubbleDirection.outgoing: 420 + 28,
        ChatBubbleDirection.incoming: 420 - 28 - 8,
      });

      expect(find.text('Write a message…'), findsOneWidget);
      for (final icon in [
        PhosphorIconsRegular.plusCircle,
        PhosphorIconsRegular.smiley,
        PhosphorIconsRegular.paperPlaneTilt,
      ]) {
        expect(
          find.descendant(
            of: find.byType(MessagesComposer),
            matching: find.byIcon(icon),
          ),
          findsOneWidget,
        );
      }
      // The composer floats over the end of the thread, 16 from the pane.
      final composer = tester.getRect(find.byType(MessagesComposer));
      expect(composer.left, view.left + 16);
      expect(composer.right, view.right - 16);
      expect(composer.bottom, view.bottom - 16);
    });

    testWidgets('the details pane shows who the conversation is with', (
      tester,
    ) async {
      await pumpMessages(tester, size: desktop);

      for (final text in [
        'Omar Rahimi',
        'Design lead at Birchline',
        'Stockholm, Sweden',
        'View profile',
        'Mutual connections',
        'Sara, Freya and 22 others',
        'Shared files',
        'calm-by-default-draft.pdf',
        '4.2 MB · Today',
        'onboarding-map.jpg',
        '1.1 MB · Today',
        'figma.com/file/onboarding-v2',
        'Link · Last week',
        'Shared groups',
        'Design Systems Guild',
      ]) {
        expect(inDetails(find.text(text)), findsOneWidget, reason: text);
      }
      expect(inDetails(find.byType(AvatarGroup)), findsOneWidget);
      expect(inDetails(find.byType(IconTile)), findsNWidgets(3));

      // The avatar stack starts on the pane's edge, under its title, and
      // the label follows it: the ring takes no room.
      final title = tester.getRect(inDetails(find.text('Mutual connections')));
      final mutuals = tester.getRect(inDetails(find.byType(AvatarGroup)));
      expect(mutuals.left, title.left);
      expect(mutuals.top, title.bottom + 10);
      expect(mutuals.size, const Size(26 + 3 * 20, 26));
      expect(
        tester.getRect(inDetails(find.text('Sara, Freya and 22 others'))).left,
        mutuals.right + 8,
      );
    });

    testWidgets('selecting a row switches the conversation and reads it', (
      tester,
    ) async {
      await pumpMessages(tester, size: desktop);
      expect(inList(find.widgetWithText(IndicatorBadge, '1')), findsOneWidget);

      await tapAndSettle(tester, inList(find.text('Sara Lindqvist')));

      // The header, the thread and the details all follow.
      expect(
        find.text('Active now · Head of Research at Birchline'),
        findsOneWidget,
      );
      expect(
        inConversation(
          find.widgetWithText(
            ChatBubble,
            'Can we move the research sync to Thursday?',
          ),
        ),
        findsOneWidget,
      );
      expect(inConversation(find.textContaining('Hey Noor!')), findsNothing);
      expect(inConversation(find.byType(TypingIndicator)), findsNothing);
      expect(inDetails(find.text('Sara Lindqvist')), findsOneWidget);
      expect(inDetails(find.text('Omar, Irina and 31 others')), findsOneWidget);
      // Her unread count is gone; the group's stays.
      expect(inList(find.widgetWithText(IndicatorBadge, '1')), findsNothing);
      expect(inList(find.widgetWithText(IndicatorBadge, '4')), findsOneWidget);

      // A group has members rather than a headline.
      await tapAndSettle(tester, inList(find.text('Design Systems Guild')));
      expect(
        find.descendant(
          of: find.byType(MessagesConversationPane),
          matching: find.text('18,402 members'),
        ),
        findsOneWidget,
      );
      expect(inDetails(find.text('18,402 members')), findsOneWidget);
      expect(inDetails(find.text('View group')), findsOneWidget);
      expect(
        inConversation(
          find.widgetWithText(
            ChatBubble,
            'Tokens v3 is live, release notes in thread',
          ),
        ),
        findsOneWidget,
      );
      // Nothing is unread any more.
      expect(inList(find.widgetWithText(IndicatorBadge, '4')), findsNothing);
    });

    testWidgets('sending appends a bubble, with the button and with Enter', (
      tester,
    ) async {
      await pumpMessages(tester, size: desktop);
      // Nothing typed: nothing sent.
      await tapAndSettle(tester, sendButton);
      expect(inConversation(find.text('Delivered')), findsNothing);

      await tester.enterText(composerField, 'On it, thank you!');
      await tapAndSettle(tester, sendButton);

      final sent = find.widgetWithText(ChatBubble, 'On it, thank you!');
      expect(inConversation(sent), findsOneWidget);
      expect(
        tester.widget<ChatBubble>(sent).direction,
        ChatBubbleDirection.outgoing,
      );
      expect(inConversation(find.text('Delivered')), findsOneWidget);
      // The field is cleared and the list's preview follows.
      expect(tester.widget<EditableText>(composerField).controller.text, '');
      expect(inList(find.text('You: On it, thank you!')), findsOneWidget);
      expect(inList(find.text('now')), findsOneWidget);

      await tester.enterText(composerField, 'Slide 14 is next.');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await settle(tester);

      expect(
        inConversation(find.widgetWithText(ChatBubble, 'Slide 14 is next.')),
        findsOneWidget,
      );
      expect(inThread('On it, thank you!'), findsOneWidget);
      // Only the newest message carries the receipt, and the newest message
      // is in view above the composer.
      expect(inConversation(find.text('Delivered')), findsOneWidget);
      final newest = tester.getRect(
        find.widgetWithText(ChatBubble, 'Slide 14 is next.'),
      );
      expect(
        newest.bottom,
        lessThan(tester.getRect(find.byType(MessagesComposer)).top),
      );
      // Enter keeps the field focused for the next message.
      expect(
        tester.widget<EditableText>(composerField).focusNode.hasFocus,
        isTrue,
      );
    });

    testWidgets('sending scrolls a thread that was scrolled back', (
      tester,
    ) async {
      // Short enough that Omar's thread does not fit.
      await pumpMessages(tester, size: const Size(1440, 700));
      final scrollable = tester.state<ScrollableState>(
        inConversation(find.byType(Scrollable)).first,
      );
      expect(scrollable.position.pixels, 0, reason: 'opens on the newest');
      expect(scrollable.position.maxScrollExtent, greaterThan(100));

      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pump();

      await tester.enterText(composerField, 'Back at the end');
      await tapAndSettle(tester, sendButton);

      expect(scrollable.position.pixels, 0);
    });

    testWidgets('the chips and the search field filter the list', (
      tester,
    ) async {
      await pumpMessages(tester, size: desktop);
      // A row's title is the name beside the time.
      String nameOf(ListTile tile) {
        final name = (tile.title as Row).children.first as Expanded;
        return (name.child as Text).data!;
      }

      List<String> names() => [
        for (final tile in tester.widgetList<ListTile>(
          inList(find.byType(ListTile)),
        ))
          nameOf(tile),
      ];

      await tapChip(tester, 'Unread');
      expect(
        tester.widget<Chip>(find.widgetWithText(Chip, 'Unread')).selected,
        isTrue,
      );
      // The open conversation stays listed beside the unread ones.
      expect(names(), [
        'Omar Rahimi',
        'Sara Lindqvist',
        'Design Systems Guild',
      ]);

      await tapChip(tester, 'Requests · 2');
      expect(names(), ['Rafael Cruz', 'Irina Volkova']);

      await tapChip(tester, 'Groups');
      expect(names(), ['Design Systems Guild']);

      await tapChip(tester, 'Focused');
      expect(names(), hasLength(9));

      await tester.enterText(
        inList(find.byType(EditableText)),
        'config',
      );
      await settle(tester);
      expect(names(), ['Julian Reyes']);

      await tester.enterText(inList(find.byType(EditableText)), 'zzz');
      await settle(tester);
      expect(names(), isEmpty);
      expect(find.text('No conversations'), findsOneWidget);
    });

    testWidgets('the info button hides the details and the bell mutes', (
      tester,
    ) async {
      await pumpMessages(tester, size: desktop);

      await tapAndSettle(tester, find.byIcon(PhosphorIconsRegular.bell));
      expect(inDetails(find.byIcon(PhosphorIconsRegular.bellSlash)), findsOne);

      final wide = tester.getSize(find.byType(MessagesConversationPane)).width;
      await tapAndSettle(tester, find.byIcon(PhosphorIconsRegular.info));
      expect(find.byType(MessagesDetailsPane), findsNothing);
      expect(
        tester.getSize(find.byType(MessagesConversationPane)).width,
        greaterThan(wide),
      );

      await tapAndSettle(tester, find.byIcon(PhosphorIconsRegular.info));
      // Still muted when it comes back.
      expect(inDetails(find.byIcon(PhosphorIconsRegular.bellSlash)), findsOne);
    });
  });

  group('as the window narrows', () {
    testWidgets('1024 wide drops the details pane', (tester) async {
      await pumpMessages(tester, size: laptop);

      expect(find.byType(MessagesConversationPane), findsOneWidget);
      expect(find.byType(MessagesDetailsPane), findsNothing);
      // With nothing to toggle, the info button goes too.
      expect(find.byIcon(PhosphorIconsRegular.info), findsNothing);
      expect(
        tester.getSize(find.byType(MessagesConversationList)).width,
        MessagesScreen.listWidth,
      );
    });

    testWidgets('768 wide shows the list and pushes the conversation', (
      tester,
    ) async {
      await pumpMessages(tester, size: tablet);

      expect(
        Theme.of(tester.element(find.byType(MessagesScreen))).formFactor,
        FormFactor.desktop,
      );
      expect(find.byType(Card), findsOneWidget);
      expect(find.byType(MessagesConversationPane), findsNothing);
      expect(find.byType(MessagesDetailsPane), findsNothing);

      await tapAndSettle(tester, find.text('Julian Reyes'));

      expect(find.byType(MessagesConversationPage), findsOneWidget);
      expect(
        inConversation(
          find.widgetWithText(
            ChatBubble,
            'See you at Config! Lounge after my talk?',
          ),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('a search and an open conversation survive a resize', (
    tester,
  ) async {
    await pumpMessages(tester, size: desktop);
    await tapAndSettle(tester, inList(find.text('Julian Reyes')));
    await tester.enterText(inList(find.byType(EditableText)), 'config');
    await settle(tester);
    expect(inList(find.byType(ListTile)), findsOneWidget);

    // Down to a phone: the list is rebuilt on the page, still filtered, and
    // the field still says why.
    tester.view.physicalSize = phone;
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(Card), findsNothing);
    expect(inList(find.byType(ListTile)), findsOneWidget);
    expect(
      tester
          .widget<EditableText>(inList(find.byType(EditableText)))
          .controller
          .text,
      'config',
    );

    // And back: Julian's conversation is still the open one.
    tester.view.physicalSize = desktop;
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(
      find.text('Active now · VP Design at Kestrel Health'),
      findsOneWidget,
    );
  });

  group('on a phone', () {
    testWidgets('the destination is the list, on the page itself', (
      tester,
    ) async {
      await pumpMessages(tester, size: phone);

      expect(
        Theme.of(tester.element(find.byType(MessagesScreen))).formFactor,
        FormFactor.mobile,
      );
      expect(find.byType(Card), findsNothing);
      expect(find.byType(MessagesConversationPane), findsNothing);
      expect(find.byType(MessagesComposer), findsNothing);
      expect(
        tester.getSize(find.byType(MessagesConversationList)).width,
        phone.width,
      );
      expect(inList(find.byType(ListTile)), findsNWidgets(9));
      // No row is highlighted: no conversation is on screen beside the list.
      expect(
        tester
            .widgetList<ListTile>(inList(find.byType(ListTile)))
            .where((tile) => tile.selected),
        isEmpty,
      );
      // The title lines up with the page margin.
      expect(tester.getTopLeft(find.text('Messages')).dx, 16);
    });

    testWidgets('a row opens the conversation as a page with its own header', (
      tester,
    ) async {
      await pumpMessages(tester, size: phone);

      await tapAndSettle(tester, find.text('Omar Rahimi'));

      final page = find.byType(MessagesConversationPage);
      expect(page, findsOneWidget);
      final bar = find.descendant(of: page, matching: find.byType(AppBar));
      // The design's 68 and the hairline the bar adds under it. A filled
      // bar keeps no margin above its toolbar with no status bar over it,
      // as in a test: its toolbar has room of its own.
      expect(tester.getSize(bar).height, 68 + 1);
      Finder inBar(Finder finder) => find.descendant(of: bar, matching: finder);
      expect(inBar(find.text('Omar Rahimi')), findsOneWidget);
      expect(inBar(find.text('Active now')), findsOneWidget);
      for (final icon in [
        PhosphorIconsRegular.caretLeft,
        PhosphorIconsRegular.phone,
        PhosphorIconsRegular.videoCamera,
      ]) {
        expect(inBar(find.byIcon(icon)), findsOneWidget);
      }
      // No details button and no bottom navigation on this page.
      expect(inBar(find.byIcon(PhosphorIconsRegular.info)), findsNothing);
      expect(
        find.descendant(of: page, matching: find.byType(BottomNavigationBar)),
        findsNothing,
      );

      expect(
        inConversation(
          find.widgetWithText(
            ChatBubble,
            'This is how we mapped ours. Might help with slide 14.',
          ),
        ),
        findsOneWidget,
      );
      expect(inConversation(find.byType(TypingIndicator)), findsOneWidget);

      // The composer's glass bar: 10 from the sides, 16 from the bottom.
      final composer = tester.getRect(find.byType(MessagesComposer));
      expect(composer.left, 10);
      expect(composer.right, phone.width - 10);
      expect(composer.bottom, phone.height - 16);

      // A phone caps a line of outgoing text at 268.
      final outgoing = tester.getRect(
        find.descendant(
          of: find.widgetWithText(
            ChatBubble,
            'Sending the deck now. Slides 12 to 18 are the ones I’m unsure '
            'about.',
          ),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect(outgoing.width, 268 + 28);
      expect(outgoing.right, phone.width - 12);

      await tapAndSettle(tester, find.byIcon(PhosphorIconsRegular.caretLeft));
      expect(page, findsNothing);
      expect(find.byType(MessagesConversationList), findsOneWidget);
    });

    testWidgets('a message sent from the page shows in the list', (
      tester,
    ) async {
      await pumpMessages(tester, size: phone);
      await tapAndSettle(tester, find.text('Mei Tanaka'));

      await tester.enterText(composerField, 'Thank you, Mei!');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await settle(tester);

      expect(
        inConversation(find.widgetWithText(ChatBubble, 'Thank you, Mei!')),
        findsOneWidget,
      );

      await tapAndSettle(tester, find.byIcon(PhosphorIconsRegular.caretLeft));
      expect(inList(find.text('You: Thank you, Mei!')), findsOneWidget);
    });

    testWidgets('the keyboard lifts the composer and the end of the thread', (
      tester,
    ) async {
      await pumpMessages(tester, size: phone);
      await tapAndSettle(tester, find.text('Omar Rahimi'));

      final typing = inConversation(find.byType(TypingIndicator));
      final restingComposer = tester.getRect(find.byType(MessagesComposer));
      final restingTyping = tester.getRect(typing);

      const keyboard = 300.0;
      tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
      addTearDown(tester.view.resetViewInsets);
      await settle(tester);

      expect(tester.takeException(), isNull);
      final composer = tester.getRect(find.byType(MessagesComposer));
      expect(composer.bottom, phone.height - keyboard - 16);
      expect(composer.height, restingComposer.height);
      // The newest message moves up with it and stays clear of the composer.
      expect(tester.getRect(typing).bottom, restingTyping.bottom - keyboard);
      expect(tester.getRect(typing).bottom, lessThan(composer.top));
    });
  });
}
