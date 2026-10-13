class PollOption {
  final String id;
  final String text;
  final int voteCount;
  final int percentage;
  final bool hasVoted;
  final List<String> voterIds;

  PollOption({
    required this.id,
    required this.text,
    this.voteCount = 0,
    this.percentage = 0,
    this.hasVoted = false,
    this.voterIds = const [],
  });

  factory PollOption.fromJson(Map<String, dynamic> json) {
    final rawVoters = json['voterIds'];
    List<String> voters = [];
    if (rawVoters is List) {
      voters = rawVoters.map((v) => v.toString()).toList();
    }

    return PollOption(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      text: (json['text'] ?? '').toString(),
      voteCount: (json['voteCount'] is num) ? (json['voteCount'] as num).toInt() : voters.length,
      percentage: (json['percentage'] is num) ? (json['percentage'] as num).toInt() : 0,
      hasVoted: json['hasVoted'] == true,
      voterIds: voters,
    );
  }

  PollOption copyWith({
    String? id,
    String? text,
    int? voteCount,
    int? percentage,
    bool? hasVoted,
    List<String>? voterIds,
  }) {
    return PollOption(
      id: id ?? this.id,
      text: text ?? this.text,
      voteCount: voteCount ?? this.voteCount,
      percentage: percentage ?? this.percentage,
      hasVoted: hasVoted ?? this.hasVoted,
      voterIds: voterIds ?? this.voterIds,
    );
  }
}

class Poll {
  final String id;
  final String tripId;
  final String? createdBy;
  final String creatorName;
  final String? creatorAvatar;
  final String question;
  final String description;
  final List<PollOption> options;
  final bool allowMultipleAnswers;
  final bool anonymous;
  final String status;
  final int totalVotes;
  final bool hasUserVoted;
  final List<String> userVotedOptionIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  Poll({
    required this.id,
    required this.tripId,
    this.createdBy,
    this.creatorName = 'Trip Leader',
    this.creatorAvatar,
    required this.question,
    this.description = '',
    required this.options,
    this.allowMultipleAnswers = false,
    this.anonymous = false,
    this.status = 'active',
    this.totalVotes = 0,
    this.hasUserVoted = false,
    this.userVotedOptionIds = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory Poll.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'];
    List<PollOption> parsedOptions = [];
    if (rawOptions is List) {
      parsedOptions = rawOptions
          .whereType<Map<String, dynamic>>()
          .map((opt) => PollOption.fromJson(opt))
          .toList();
    }

    final rawVotedOpts = json['userVotedOptionIds'];
    List<String> votedOpts = [];
    if (rawVotedOpts is List) {
      votedOpts = rawVotedOpts.map((v) => v.toString()).toList();
    }

    DateTime parseDate(dynamic d) {
      if (d == null) return DateTime.now();
      if (d is DateTime) return d;
      try {
        return DateTime.parse(d.toString());
      } catch (_) {
        return DateTime.now();
      }
    }

    return Poll(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      tripId: (json['tripId'] ?? '').toString(),
      createdBy: json['createdBy']?.toString(),
      creatorName: (json['creatorName'] ?? 'Trip Leader').toString(),
      creatorAvatar: json['creatorAvatar']?.toString(),
      question: (json['question'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      options: parsedOptions,
      allowMultipleAnswers: json['allowMultipleAnswers'] == true,
      anonymous: json['anonymous'] == true,
      status: (json['status'] ?? 'active').toString(),
      totalVotes: (json['totalVotes'] is num) ? (json['totalVotes'] as num).toInt() : 0,
      hasUserVoted: json['hasUserVoted'] == true || votedOpts.isNotEmpty,
      userVotedOptionIds: votedOpts,
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }

  Poll copyWith({
    String? id,
    String? tripId,
    String? createdBy,
    String? creatorName,
    String? creatorAvatar,
    String? question,
    String? description,
    List<PollOption>? options,
    bool? allowMultipleAnswers,
    bool? anonymous,
    String? status,
    int? totalVotes,
    bool? hasUserVoted,
    List<String>? userVotedOptionIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Poll(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      createdBy: createdBy ?? this.createdBy,
      creatorName: creatorName ?? this.creatorName,
      creatorAvatar: creatorAvatar ?? this.creatorAvatar,
      question: question ?? this.question,
      description: description ?? this.description,
      options: options ?? this.options,
      allowMultipleAnswers: allowMultipleAnswers ?? this.allowMultipleAnswers,
      anonymous: anonymous ?? this.anonymous,
      status: status ?? this.status,
      totalVotes: totalVotes ?? this.totalVotes,
      hasUserVoted: hasUserVoted ?? this.hasUserVoted,
      userVotedOptionIds: userVotedOptionIds ?? this.userVotedOptionIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
