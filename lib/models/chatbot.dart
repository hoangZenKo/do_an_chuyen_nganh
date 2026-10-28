enum ChatAnswerStatus { answered, insufficientEvidence }

Map<String, dynamic> _object(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Invalid chatbot object');
  }
  return value;
}

String _text(Map<String, dynamic> json, String key, {bool empty = false}) {
  final value = json[key];
  if (value is! String || (!empty && value.trim().isEmpty)) {
    throw FormatException('Invalid chatbot $key');
  }
  return value;
}

class ChatSource {
  const ChatSource(
      {required this.id,
      required this.documentId,
      required this.contentHash,
      required this.title,
      required this.heading});

  final String id;
  final String documentId;
  final String contentHash;
  final String title;
  final String heading;

  factory ChatSource.fromJson(Object? value) {
    final json = _object(value);
    return ChatSource(
        id: _text(json, 'id'),
        documentId: _text(json, 'documentId'),
        contentHash: _text(json, 'contentHash'),
        title: _text(json, 'title'),
        heading: _text(json, 'heading', empty: true));
  }
}

class ChatSourceDetail {
  const ChatSourceDetail({required this.source, required this.text});
  final ChatSource source;
  final String text;

  factory ChatSourceDetail.fromJson(Object? value) {
    final json = _object(value);
    return ChatSourceDetail(
        source: ChatSource.fromJson(json), text: _text(json, 'text'));
  }
}

class ChatAnswer {
  const ChatAnswer(
      {required this.requestId,
      required this.status,
      required this.answer,
      required this.sources});

  final String requestId;
  final ChatAnswerStatus status;
  final String answer;
  final List<ChatSource> sources;

  factory ChatAnswer.fromJson(Object? value) {
    final json = _object(value);
    final status = switch (json['status']) {
      'answered' => ChatAnswerStatus.answered,
      'insufficient_evidence' => ChatAnswerStatus.insufficientEvidence,
      _ => throw const FormatException('Invalid chatbot status'),
    };
    final rawSources = json['sources'];
    if (rawSources is! List || rawSources.length > 3) {
      throw const FormatException('Invalid chatbot sources');
    }
    final sources = rawSources.map(ChatSource.fromJson).toList(growable: false);
    if ((status == ChatAnswerStatus.answered && sources.isEmpty) ||
        (status == ChatAnswerStatus.insufficientEvidence &&
            sources.isNotEmpty) ||
        sources.map((source) => source.id).toSet().length != sources.length) {
      throw const FormatException('Invalid chatbot citations');
    }
    return ChatAnswer(
        requestId: _text(json, 'requestId'),
        status: status,
        answer: _text(json, 'answer'),
        sources: List.unmodifiable(sources));
  }
}
