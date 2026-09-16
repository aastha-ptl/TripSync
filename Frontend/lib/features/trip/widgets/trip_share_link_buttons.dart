import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tripsync/core/theme/app_colors.dart';

class TripShareLinkButtons extends StatelessWidget {
  final String inviteLink;

  const TripShareLinkButtons({
    super.key,
    required this.inviteLink,
  });

  Future<void> _copyLink(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: inviteLink));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invite link copied!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _shareToWhatsApp(BuildContext context) async {
    final message = 'Join my trip on TripSync!\n\n$inviteLink';
    final encoded = Uri.encodeComponent(message);
    final appUri = Uri.parse('whatsapp://send?text=$encoded');
    final webUri = Uri.parse('https://wa.me/?text=$encoded');

    try {
      final launched = await launchUrl(appUri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      try {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open WhatsApp')),
          );
        }
      }
    }
  }

  Future<void> _shareToSms(BuildContext context) async {
    final message = 'Join my trip on TripSync!\n\n$inviteLink';
    final encoded = Uri.encodeComponent(message);
    final smsUri = Uri.parse('sms:?body=$encoded');

    try {
      final launched = await launchUrl(smsUri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(smsUri);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Messages app')),
        );
      }
    }
  }

  Future<void> _shareToTelegram(BuildContext context) async {
    final message = 'Join my trip on TripSync!\n\n$inviteLink';
    final encodedMsg = Uri.encodeComponent(message);
    final encodedLink = Uri.encodeComponent(inviteLink);
    final appUri = Uri.parse('tg://msg?text=$encodedMsg');
    final webUri = Uri.parse(
      'https://t.me/share/url?url=$encodedLink&text=${Uri.encodeComponent("Join my trip on TripSync!")}',
    );

    try {
      final launched = await launchUrl(appUri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      try {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open Telegram')),
          );
        }
      }
    }
  }

  Widget _buildCircleButton({
    required Widget icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.28),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(child: icon),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildCircleButton(
              icon: const Icon(
                Icons.copy_rounded,
                color: Colors.white,
                size: 21,
              ),
              color: AppColors.primary,
              label: 'Copy link',
              onTap: () => _copyLink(context),
            ),
            _buildCircleButton(
              icon: const FaIcon(
                FontAwesomeIcons.whatsapp,
                color: Colors.white,
                size: 22,
              ),
              color: const Color(0xFF25D366),
              label: 'WhatsApp',
              onTap: () => _shareToWhatsApp(context),
            ),
            _buildCircleButton(
              icon: const Icon(
                Icons.sms_rounded,
                color: Colors.white,
                size: 21,
              ),
              color: const Color(0xFF0284C7),
              label: 'Message',
              onTap: () => _shareToSms(context),
            ),
            _buildCircleButton(
              icon: const FaIcon(
                FontAwesomeIcons.telegram,
                color: Colors.white,
                size: 22,
              ),
              color: const Color(0xFF0088CC),
              label: 'Telegram',
              onTap: () => _shareToTelegram(context),
            ),
          ],
        ),
      ),
    );
  }
}
