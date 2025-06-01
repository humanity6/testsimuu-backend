enum QuestionType {
  multipleChoice,
  openEnded,
  calculation
}

class Quiz {
  final String id;
  final String title;
  final String category;
  final String difficulty;
  final List<Question> questions;
  final int timeLimit; // in minutes

  Quiz({
    required this.id,
    required this.title,
    required this.category,
    required this.difficulty,
    required this.questions,
    this.timeLimit = 30,
  });
  
  factory Quiz.fromJson(Map<String, dynamic> json) {
    List<Question> questionsList = [];
    if (json['questions'] != null) {
      questionsList = (json['questions'] as List)
          .map((q) => Question.fromJson(q))
          .toList();
    }
    
    return Quiz(
      id: json['id'].toString(),
      title: json['title'] ?? '',
      category: json['category'] ?? '',
      difficulty: json['difficulty'] ?? 'MEDIUM',
      questions: questionsList,
      timeLimit: json['time_limit'] ?? 30,
    );
  }
}

class Question {
  final String id;
  final String text;
  final QuestionType type;
  final List<Option>? options;
  final String? correctAnswer;
  final List<String>? solutionSteps;
  final String difficulty;
  final String? topicId;
  final String? subject;
  final String? explanation;
  final int? points;
  final Map<String, dynamic>? calculationParams;

  Question({
    required this.id,
    required this.text,
    required this.type,
    this.options,
    this.correctAnswer,
    this.solutionSteps,
    this.difficulty = 'MEDIUM',
    this.topicId,
    this.subject,
    this.explanation,
    this.points,
    this.calculationParams,
  });
  
  factory Question.fromJson(Map<String, dynamic> json) {
    List<Option>? optionsList;
    if (json['options'] != null) {
      optionsList = (json['options'] as List)
          .map((o) => Option.fromJson(o))
          .toList();
    }
    
    List<String>? stepsList;
    if (json['solution_steps'] != null) {
      stepsList = (json['solution_steps'] as List)
          .map((s) => s.toString())
          .toList();
    }
    
    QuestionType questionType = QuestionType.multipleChoice;
    if (json['type'] != null) {
      if (json['type'] == 'openEnded' || json['type'] == 'OPEN_ENDED') {
        questionType = QuestionType.openEnded;
      } else if (json['type'] == 'calculation' || json['type'] == 'CALCULATION') {
        questionType = QuestionType.calculation;
      }
    }
    
    // Parse calculation parameters
    Map<String, dynamic>? calculationParams;
    if (questionType == QuestionType.calculation) {
      if (json['calculation_params'] != null) {
        calculationParams = json['calculation_params'] as Map<String, dynamic>;
      } else if (json['model_calculation_logic'] != null) {
        calculationParams = json['model_calculation_logic'] as Map<String, dynamic>;
      }
    }
    
    return Question(
      id: json['id'].toString(),
      text: json['text'] ?? '',
      type: questionType,
      options: optionsList,
      correctAnswer: json['correct_answer'],
      solutionSteps: stepsList,
      difficulty: json['difficulty'] ?? 'MEDIUM',
      topicId: json['topic_id'],
      subject: json['subject'],
      explanation: json['explanation'],
      points: json['points'],
      calculationParams: calculationParams,
    );
  }
  
  Map<String, dynamic> toJson() {
    String typeString = 'MULTIPLE_CHOICE';
    if (type == QuestionType.openEnded) {
      typeString = 'OPEN_ENDED';
    } else if (type == QuestionType.calculation) {
      typeString = 'CALCULATION';
    }
    
    final Map<String, dynamic> result = {
      'id': id,
      'text': text,
      'type': typeString,
      'options': options?.map((o) => o.toJson()).toList(),
      'correct_answer': correctAnswer,
      'solution_steps': solutionSteps,
      'difficulty': difficulty,
      'topic_id': topicId,
      'subject': subject,
      'explanation': explanation,
      'points': points,
    };
    
    if (calculationParams != null && type == QuestionType.calculation) {
      result['calculation_params'] = calculationParams;
    }
    
    return result;
  }
}

class Option {
  final String id;
  final String text;

  Option({
    required this.id,
    required this.text,
  });
  
  factory Option.fromJson(Map<String, dynamic> json) {
    // Debug the incoming JSON
    print('Option.fromJson: $json');
    
    // Extract the ID, handling different possible field names and types
    String optionId = '';
    if (json.containsKey('id')) {
      // Convert ID to string regardless of original type (int, string, etc.)
      optionId = json['id'].toString();
      print('Parsed option ID: $optionId');
    }
    
    // Extract the text, handling different possible field names
    String optionText = '';
    if (json.containsKey('text')) {
      optionText = json['text'].toString();
    } else if (json.containsKey('choice_text')) {
      optionText = json['choice_text'].toString();
    } else if (json.containsKey('content')) {
      optionText = json['content'].toString();
    } else {
      // If no text field is found, create a placeholder
      optionText = 'Option $optionId';
    }
    
    return Option(
      id: optionId,
      text: optionText,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'choice_text': text,
      'text': text,
    };
  }
} 