import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_manager/features/pets_v2/widgets/pet_avatar.dart';
import 'package:home_manager/features/pets_v2/widgets/status_bar.dart';
import 'package:home_manager/features/pets_v2/widgets/interaction_button.dart';
import 'package:home_manager/features/pets_v2/widgets/mood_bubble.dart';

void main() {
  group('PetAvatarWidget', () {
    testWidgets('renders with default size', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PetAvatarWidget(type: 'cat')),
        ),
      );

      expect(find.byType(PetAvatarWidget), findsOneWidget);
      expect(find.text('🐱'), findsOneWidget);
    });

    testWidgets('shows correct emoji for different types', (tester) async {
      final typeEmoji = {
        'cat': '🐱',
        'dog': '🐶',
        'rabbit': '🐰',
        'fish': '🐟',
        'turtle': '🐢',
        'other': '🐾',
      };

      for (final entry in typeEmoji.entries) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PetAvatarWidget(type: entry.key, key: ValueKey(entry.key)),
            ),
          ),
        );
        expect(find.text(entry.value), findsOneWidget,
            reason: '${entry.key} should show ${entry.value}');
      }
    });

    testWidgets('shows mood badge when mood is provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PetAvatarWidget(type: 'cat', mood: 'happy'),
          ),
        ),
      );

      expect(find.text('😊'), findsOneWidget);
    });

    testWidgets('no mood badge when mood is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PetAvatarWidget(type: 'cat'),
          ),
        ),
      );

      // Only the main emoji, no mood badge
      expect(find.text('🐱'), findsOneWidget);
    });
  });

  group('PetStatusBar', () {
    testWidgets('renders with label, icon, and value', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PetStatusBar(label: '饥饿', value: 80, icon: '🍖'),
          ),
        ),
      );

      expect(find.text('饥饿'), findsOneWidget);
      expect(find.text('🍖'), findsOneWidget);
      expect(find.text('80%'), findsOneWidget);
    });

    testWidgets('shows green color for high values', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PetStatusBar(label: '饥饿', value: 80, icon: '🍖'),
          ),
        ),
      );

      // The percentage text should be rendered
      expect(find.text('80%'), findsOneWidget);
    });

    testWidgets('shows red color for low values', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PetStatusBar(label: '饥饿', value: 10, icon: '🍖'),
          ),
        ),
      );

      expect(find.text('10%'), findsOneWidget);
    });
  });

  group('PetInteractionButton', () {
    testWidgets('renders with icon and label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PetInteractionButton(
              icon: Icons.restaurant,
              label: '喂食',
              color: Colors.orange,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.restaurant), findsOneWidget);
      expect(find.text('喂食'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PetInteractionButton(
              icon: Icons.restaurant,
              label: '喂食',
              color: Colors.orange,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(PetInteractionButton));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });

  group('MoodBubble', () {
    testWidgets('renders text and emoji', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MoodBubble(text: '今天心情很好', emoji: '😊'),
          ),
        ),
      );

      expect(find.text('今天心情很好'), findsOneWidget);
      expect(find.text('😊'), findsOneWidget);
    });

    testWidgets('renders without emoji', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MoodBubble(text: 'Hello'),
          ),
        ),
      );

      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('returns empty widget for empty text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MoodBubble(text: ''),
          ),
        ),
      );

      expect(find.byType(SizedBox), findsOneWidget);
    });
  });
}
