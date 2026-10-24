/// Kosakata yang dipelajari selama sesi Voice Tutor (ala GoPrep session feedback).
class VoiceTutorVocabulary {
  final String word;
  final String meaning;
  final String level;

  const VoiceTutorVocabulary({
    required this.word,
    required this.meaning,
    this.level = 'Krama',
  });

  factory VoiceTutorVocabulary.fromJson(Map<String, dynamic> json) {
    return VoiceTutorVocabulary(
      word: (json['word'] ?? '').toString(),
      meaning: (json['meaning'] ?? '').toString(),
      level: (json['level'] ?? 'Krama').toString(),
    );
  }
}

/// Hasil respon interaktif Voice Tutor dari backend (POST /api/voice-tutor/interact).
class VoiceTutorResult {
  final bool mock;
  final String transkripsiSiswa;
  final String balasanTeks;
  final String expression;
  final String? suggestedRepeat;
  final List<VoiceTutorVocabulary> vocabulary;
  final String? audioBase64;
  final String? audioUrl;

  const VoiceTutorResult({
    this.mock = false,
    required this.transkripsiSiswa,
    required this.balasanTeks,
    this.expression = 'happy',
    this.suggestedRepeat,
    this.vocabulary = const [],
    this.audioBase64,
    this.audioUrl,
  });

  factory VoiceTutorResult.fromJson(Map<String, dynamic> json) {
    final vocabList = <VoiceTutorVocabulary>[];
    if (json['vocabulary'] is List) {
      for (final item in json['vocabulary'] as List) {
        if (item is Map<String, dynamic>) {
          vocabList.add(VoiceTutorVocabulary.fromJson(item));
        } else if (item is Map) {
          vocabList.add(VoiceTutorVocabulary.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    return VoiceTutorResult(
      mock: json['mock'] == true,
      transkripsiSiswa: (json['transkripsi_siswa'] ?? json['transkripsi'] ?? '').toString(),
      balasanTeks: (json['balasan_teks'] ?? json['feedback_text'] ?? '').toString(),
      expression: (json['expression'] ?? 'happy').toString(),
      suggestedRepeat: json['suggested_repeat']?.toString(),
      vocabulary: vocabList,
      audioBase64: json['audio_base64']?.toString(),
      audioUrl: json['audio_url']?.toString(),
    );
  }
}
