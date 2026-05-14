class JobDetails {
  final String hrEmail;
  final String location;
  final String generatedSubject;
  final String generatedBody;

  JobDetails({
    required this.hrEmail,
    required this.location,
    required this.generatedSubject,
    required this.generatedBody,
  });

  factory JobDetails.fromJson(Map<String, dynamic> json) {
    return JobDetails(
      hrEmail: json['hr_email'] ?? '',
      location: json['location'] ?? '',
      generatedSubject: json['generated_subject'] ?? '',
      generatedBody: json['generated_body'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hr_email': hrEmail,
      'location': location,
      'generated_subject': generatedSubject,
      'generated_body': generatedBody,
    };
  }

  @override
  String toString() {
    return 'JobDetails(hrEmail: $hrEmail, location: $location)';
  }
}
