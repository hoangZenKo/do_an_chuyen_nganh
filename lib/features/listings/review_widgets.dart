import 'package:flutter/material.dart';

import '../../core/utils/format.dart';
import '../../models/room_review.dart';
import 'listing_widgets.dart';

class ReviewContent extends StatelessWidget {
  const ReviewContent(
      {super.key, required this.review, this.management = false});

  final RoomReview review;
  final bool management;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (management && review.roomName != null) ...[
            Text('${review.roomName} · ${review.propertyName ?? ''}',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
          ],
          Text(
              '${review.overall.toStringAsFixed(1)}/5 · ${formatDate(review.createdAt)}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Người thuê có lịch sử hợp đồng',
              style: TextStyle(color: kAirbnbMuted)),
          const SizedBox(height: 12),
          Wrap(spacing: 16, runSpacing: 8, children: [
            for (final entry in reviewCriteria.entries)
              Text('${entry.value}: ${review.scores[entry.key]}/5'),
          ]),
          const SizedBox(height: 12),
          Text(review.body),
          if (management) ...[
            const SizedBox(height: 12),
            Text('Đánh giá: ${reviewStatusLabel(review.status)}'),
            if (review.moderationNote != null)
              Text('Ghi chú kiểm duyệt: ${review.moderationNote}'),
          ],
          if (review.replyBody != null) ...[
            const Divider(height: 28),
            const Text('Phản hồi của chủ trọ',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(review.replyBody!),
            if (management) ...[
              const SizedBox(height: 8),
              Text('Phản hồi: ${reviewStatusLabel(review.replyStatus ?? '')}'),
              if (review.replyModerationNote != null)
                Text('Ghi chú kiểm duyệt: ${review.replyModerationNote}'),
            ],
          ],
        ],
      );
}
