# This is an auto-generated Django model module.
# You'll have to do the following manually to clean this up:
#   * Rearrange models' order
#   * Make sure each model has one field with primary_key=True
#   * Make sure each ForeignKey and OneToOneField has `on_delete` set to the desired behavior
#   * Remove `managed = False` lines if you wish to allow Django to create, modify, and delete the table
# Feel free to rename the models, but don't rename db_table values or field names.
from django.db import models


class AffiliatesAffiliate(models.Model):
    name = models.CharField(max_length=100)
    email = models.CharField(max_length=254)
    website = models.CharField(max_length=200, blank=True, null=True)
    description = models.TextField(blank=True, null=True)
    commission_model = models.CharField(max_length=20)
    commission_rate = models.DecimalField(max_digits=10, decimal_places=5)  # max_digits and decimal_places have been guessed, as this database handles decimal fields as float
    fixed_fee = models.DecimalField(max_digits=10, decimal_places=5)  # max_digits and decimal_places have been guessed, as this database handles decimal fields as float
    payment_method = models.CharField(max_length=100, blank=True, null=True)
    payment_details = models.JSONField(blank=True, null=True)
    tracking_code = models.CharField(unique=True, max_length=20)
    is_active = models.BooleanField()
    created_at = models.DateTimeField()
    updated_at = models.DateTimeField()
    user = models.OneToOneField('UsersUser', models.DO_NOTHING)

    class Meta:
        managed = False
        db_table = 'affiliates_affiliate'


class AffiliatesAffiliatelink(models.Model):
    name = models.CharField(max_length=100)
    link_type = models.CharField(max_length=20)
    target_url = models.CharField(max_length=200)
    object_id = models.PositiveIntegerField(blank=True, null=True)
    tracking_id = models.CharField(unique=True, max_length=50)
    utm_medium = models.CharField(max_length=50)
    utm_campaign = models.CharField(max_length=50, blank=True, null=True)
    click_count = models.PositiveIntegerField()
    is_active = models.BooleanField()
    created_at = models.DateTimeField()
    updated_at = models.DateTimeField()
    affiliate = models.ForeignKey(AffiliatesAffiliate, models.DO_NOTHING)
    content_type = models.ForeignKey('DjangoContentType', models.DO_NOTHING, blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'affiliates_affiliatelink'


class AffiliatesAffiliatepayment(models.Model):
    amount = models.DecimalField(max_digits=10, decimal_places=5)  # max_digits and decimal_places have been guessed, as this database handles decimal fields as float
    currency = models.CharField(max_length=3)
    payment_method = models.CharField(max_length=50)
    transaction_id = models.CharField(max_length=100, blank=True, null=True)
    status = models.CharField(max_length=20)
    period_start = models.DateField()
    period_end = models.DateField()
    sumup_checkout_id = models.CharField(max_length=100, blank=True, null=True)
    sumup_transaction_code = models.CharField(max_length=100, blank=True, null=True)
    notes = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField()
    updated_at = models.DateTimeField()
    affiliate = models.ForeignKey(AffiliatesAffiliate, models.DO_NOTHING)

    class Meta:
        managed = False
        db_table = 'affiliates_affiliatepayment'


class AffiliatesAffiliatepaymentConversions(models.Model):
    affiliatepayment = models.ForeignKey(AffiliatesAffiliatepayment, models.DO_NOTHING)
    conversion = models.ForeignKey('AffiliatesConversion', models.DO_NOTHING)

    class Meta:
        managed = False
        db_table = 'affiliates_affiliatepayment_conversions'
        unique_together = (('affiliatepayment', 'conversion'),)


class AffiliatesClickevent(models.Model):
    session_id = models.CharField(max_length=100, blank=True, null=True)
    ip_address = models.CharField(max_length=39, blank=True, null=True)
    user_agent = models.TextField(blank=True, null=True)
    referrer_url = models.CharField(max_length=200, blank=True, null=True)
    timestamp = models.DateTimeField()
    affiliate = models.ForeignKey(AffiliatesAffiliate, models.DO_NOTHING)
    affiliate_link = models.ForeignKey(AffiliatesAffiliatelink, models.DO_NOTHING)
    user = models.ForeignKey('UsersUser', models.DO_NOTHING, blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'affiliates_clickevent'


class AffiliatesConversion(models.Model):
    conversion_type = models.CharField(max_length=20)
    conversion_value = models.DecimalField(max_digits=10, decimal_places=5)  # max_digits and decimal_places have been guessed, as this database handles decimal fields as float
    commission_amount = models.DecimalField(max_digits=10, decimal_places=5)  # max_digits and decimal_places have been guessed, as this database handles decimal fields as float
    ip_address = models.CharField(max_length=39, blank=True, null=True)
    user_agent = models.TextField(blank=True, null=True)
    referrer_url = models.CharField(max_length=200, blank=True, null=True)
    is_verified = models.BooleanField()
    is_paid = models.BooleanField()
    conversion_date = models.DateTimeField()
    verification_date = models.DateTimeField(blank=True, null=True)
    affiliate = models.ForeignKey(AffiliatesAffiliate, models.DO_NOTHING)
    affiliate_link = models.ForeignKey(AffiliatesAffiliatelink, models.DO_NOTHING, blank=True, null=True)
    payment = models.ForeignKey('SubscriptionsPayment', models.DO_NOTHING, blank=True, null=True)
    subscription = models.ForeignKey('SubscriptionsUsersubscription', models.DO_NOTHING, blank=True, null=True)
    user = models.ForeignKey('UsersUser', models.DO_NOTHING)
    voucher_code = models.ForeignKey('AffiliatesVouchercode', models.DO_NOTHING, blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'affiliates_conversion'


class AffiliatesVouchercode(models.Model):
    code = models.CharField(unique=True, max_length=20)
    description = models.CharField(max_length=200)
    code_type = models.CharField(max_length=20)
    discount_value = models.DecimalField(max_digits=10, decimal_places=5)  # max_digits and decimal_places have been guessed, as this database handles decimal fields as float
    valid_from = models.DateTimeField()
    valid_until = models.DateTimeField(blank=True, null=True)
    max_uses = models.PositiveIntegerField()
    current_uses = models.PositiveIntegerField()
    minimum_purchase = models.DecimalField(max_digits=10, decimal_places=5)  # max_digits and decimal_places have been guessed, as this database handles decimal fields as float
    applicable_products = models.JSONField(blank=True, null=True)
    is_active = models.BooleanField()
    created_at = models.DateTimeField()
    updated_at = models.DateTimeField()
    affiliate = models.ForeignKey(AffiliatesAffiliate, models.DO_NOTHING)

    class Meta:
        managed = False
        db_table = 'affiliates_vouchercode'


class AiIntegrationAicontentalert(models.Model):
    alert_type = models.CharField(max_length=30)
    summary_of_potential_change = models.TextField()
    detailed_explanation = models.TextField(blank=True, null=True)
    source_urls = models.JSONField(blank=True, null=True)
    ai_confidence_score = models.FloatField(blank=True, null=True)
    priority = models.CharField(max_length=10)
    status = models.CharField(max_length=20)
    admin_notes = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField()
    reviewed_at = models.DateTimeField(blank=True, null=True)
    action_taken = models.TextField(blank=True, null=True)
    related_question = models.ForeignKey('QuestionsQuestion', models.DO_NOTHING, blank=True, null=True)
    related_topic = models.ForeignKey('QuestionsTopic', models.DO_NOTHING, blank=True, null=True)
    reviewed_by_admin = models.ForeignKey('UsersUser', models.DO_NOTHING, blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'ai_integration_aicontentalert'


class AiIntegrationAievaluationlog(models.Model):
    prompt_used = models.TextField()
    ai_response = models.TextField()
    processing_time_ms = models.IntegerField()
    success = models.BooleanField()
    error_message = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField()
    user_answer = models.ForeignKey('AssessmentUseranswer', models.DO_NOTHING)

    class Meta:
        managed = False
        db_table = 'ai_integration_aievaluationlog'


class AiIntegrationAifeedbacktemplate(models.Model):
    template_name = models.CharField(unique=True, max_length=100)
    question_type = models.CharField(max_length=20)
    template_content = models.TextField()
    is_active = models.BooleanField()
    created_at = models.DateTimeField()
    updated_at = models.DateTimeField()

    class Meta:
        managed = False
        db_table = 'ai_integration_aifeedbacktemplate'


class AiIntegrationChatbotconversation(models.Model):
    title = models.CharField(max_length=200, blank=True, null=True)
    created_at = models.DateTimeField()
    updated_at = models.DateTimeField()
    is_active = models.BooleanField()
    user = models.ForeignKey('UsersUser', models.DO_NOTHING)

    class Meta:
        managed = False
        db_table = 'ai_integration_chatbotconversation'


class AiIntegrationChatbotmessage(models.Model):
    role = models.CharField(max_length=10)
    content = models.TextField()
    created_at = models.DateTimeField()
    processing_time_ms = models.IntegerField(blank=True, null=True)
    conversation = models.ForeignKey(AiIntegrationChatbotconversation, models.DO_NOTHING)

    class Meta:
        managed = False
        db_table = 'ai_integration_chatbotmessage'


class AiIntegrationContentupdatescanconfig(models.Model):
    name = models.CharField(max_length=100)
    frequency = models.CharField(max_length=10)
    max_questions_per_scan = models.IntegerField()
    is_active = models.BooleanField()
    prompt_template = models.TextField()
    last_run = models.DateTimeField(blank=True, null=True)
    next_scheduled_run = models.DateTimeField(blank=True, null=True)
    created_at = models.DateTimeField()
    updated_at = models.DateTimeField()
    created_by = models.ForeignKey('UsersUser', models.DO_NOTHING, blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'ai_integration_contentupdatescanconfig'


class AiIntegrationContentupdatescanconfigExams(models.Model):
    contentupdatescanconfig = models.ForeignKey(AiIntegrationContentupdatescanconfig, models.DO_NOTHING)
    exam = models.ForeignKey('ExamsExam', models.DO_NOTHING)

    class Meta:
        managed = False
        db_table = 'ai_integration_contentupdatescanconfig_exams'
        unique_together = (('contentupdatescanconfig', 'exam'),)


class AiIntegrationContentupdatescanlog(models.Model):
    start_time = models.DateTimeField()
    end_time = models.DateTimeField(blank=True, null=True)
    topics_scanned = models.JSONField(blank=True, null=True)
    questions_scanned = models.IntegerField()
    alerts_generated = models.IntegerField()
    status = models.CharField(max_length=20)
    error_message = models.TextField(blank=True, null=True)
    scan_config = models.ForeignKey(AiIntegrationContentupdatescanconfig, models.DO_NOTHING)

    class Meta:
        managed = False
        db_table = 'ai_integration_contentupdatescanlog'


class AnalyticsStudysession(models.Model):
    start_time = models.DateTimeField()
    end_time = models.DateTimeField()
    topics_studied = models.JSONField()
    questions_answered = models.IntegerField()
    correct_answers = models.IntegerField()
    device_info = models.CharField(max_length=255, blank=True, null=True)
    session_source = models.CharField(max_length=10)
    user = models.ForeignKey('UsersUser', models.DO_NOTHING)

    class Meta:
        managed = False
        db_table = 'analytics_studysession'


class AnalyticsUserperformancerecord(models.Model):
    question_type = models.CharField(max_length=20, blank=True, null=True)
    difficulty = models.CharField(max_length=10, blank=True, null=True)
    date_recorded = models.DateField()
    questions_answered = models.IntegerField()
    correct_answers = models.IntegerField()
    partially_correct_answers = models.IntegerField()
    total_points_earned = models.FloatField()
    total_points_possible = models.FloatField()
    total_time_spent_seconds = models.IntegerField()
    accuracy = models.FloatField(blank=True, null=True)
    average_time_per_question = models.FloatField(blank=True, null=True)
    topic = models.ForeignKey('QuestionsTopic', models.DO_NOTHING, blank=True, null=True)
    user = models.ForeignKey('UsersUser', models.DO_NOTHING)

    class Meta:
        managed = False
        db_table = 'analytics_userperformancerecord'
        unique_together = (('user', 'topic', 'question_type', 'difficulty', 'date_recorded'),)


class AnalyticsUserprogress(models.Model):
    total_questions_in_topic = models.IntegerField()
    questions_attempted = models.IntegerField()
    questions_mastered = models.IntegerField()
    proficiency_level = models.CharField(max_length=20)
    last_activity_date = models.DateTimeField()
    created_at = models.DateTimeField()
    updated_at = models.DateTimeField()
    topic = models.ForeignKey('QuestionsTopic', models.DO_NOTHING)
    user = models.ForeignKey('UsersUser', models.DO_NOTHING)

    class Meta:
        managed = False
        db_table = 'analytics_userprogress'
        unique_together = (('user', 'topic'),)


class AssessmentExamsession(models.Model):
    title = models.CharField(max_length=255, blank=True, null=True)
    session_type = models.CharField(max_length=20)
    start_time = models.DateTimeField()
    end_time_expected = models.DateTimeField()
    actual_end_time = models.DateTimeField(blank=True, null=True)
    status = models.CharField(max_length=20)
    total_score_achieved = models.FloatField(blank=True, null=True)
    total_possible_score = models.FloatField()
    pass_threshold = models.FloatField()
    passed = models.BooleanField(blank=True, null=True)
    time_limit_seconds = models.IntegerField()
    metadata = models.JSONField(blank=True, null=True)
    created_at = models.DateTimeField()
    user = models.ForeignKey('UsersUser', models.DO_NOTHING)
    exam = models.ForeignKey('ExamsExam', models.DO_NOTHING)

    class Meta:
        managed = False
        db_table = 'assessment_examsession'


class AssessmentExamsessionQuestions(models.Model):
    display_order = models.IntegerField()
    question_weight = models.FloatField()
    exam_session = models.ForeignKey(AssessmentExamsession, models.DO_NOTHING)
    question = models.ForeignKey('QuestionsQuestion', models.DO_NOTHING)

    class Meta:
        managed = False
        db_table = 'assessment_examsession_questions'
        unique_together = (('exam_session', 'question'),)


class AssessmentUseranswer(models.Model):
    submitted_answer_text = models.TextField(blank=True, null=True)
    submitted_calculation_input = models.JSONField(blank=True, null=True)
    raw_score = models.FloatField(blank=True, null=True)
    weighted_score = models.FloatField(blank=True, null=True)
    max_possible_score = models.FloatField()
    is_correct = models.BooleanField(blank=True, null=True)
    ai_feedback = models.TextField(blank=True, null=True)
    human_feedback = models.TextField(blank=True, null=True)
    evaluation_status = models.CharField(max_length=20)
    time_spent_seconds = models.IntegerField(blank=True, null=True)
    submission_time = models.DateTimeField()
    retry_count = models.IntegerField()
    exam_session = models.ForeignKey(AssessmentExamsession, models.DO_NOTHING, blank=True, null=True)
    question = models.ForeignKey('QuestionsQuestion', models.DO_NOTHING)
    user = models.ForeignKey('UsersUser', models.DO_NOTHING)

    class Meta:
        managed = False
        db_table = 'assessment_useranswer'


class AssessmentUseranswerMcqChoices(models.Model):
    mcq_choice = models.ForeignKey('QuestionsMcqchoice', models.DO_NOTHING)
    user_answer = models.ForeignKey(AssessmentUseranswer, models.DO_NOTHING)

    class Meta:
        managed = False
        db_table = 'assessment_useranswer_mcq_choices'
        unique_together = (('user_answer', 'mcq_choice'),)


class AuthGroup(models.Model):
    name = models.CharField(unique=True, max_length=150)

    class Meta:
        managed = False
        db_table = 'auth_group'


class AuthGroupPermissions(models.Model):
    group = models.ForeignKey(AuthGroup, models.DO_NOTHING)
    permission = models.ForeignKey('AuthPermission', models.DO_NOTHING)

    class Meta:
        managed = False
        db_table = 'auth_group_permissions'
        unique_together = (('group', 'permission'),)


class AuthPermission(models.Model):
    content_type = models.ForeignKey('DjangoContentType', models.DO_NOTHING)
    codename = models.CharField(max_length=100)
    name = models.CharField(max_length=255)

    class Meta:
        managed = False
        db_table = 'auth_permission'
        unique_together = (('content_type', 'codename'),)


class DjangoAdminLog(models.Model):
    object_id = models.TextField(blank=True, null=True)
    object_repr = models.CharField(max_length=200)
    action_flag = models.PositiveSmallIntegerField()
    change_message = models.TextField()
    content_type = models.ForeignKey('DjangoContentType', models.DO_NOTHING, blank=True, null=True)
    user = models.ForeignKey('UsersUser', models.DO_NOTHING)
    action_time = models.DateTimeField()

    class Meta:
        managed = False
        db_table = 'django_admin_log'


class DjangoContentType(models.Model):
    app_label = models.CharField(max_length=100)
    model = models.CharField(max_length=100)

    class Meta:
        managed = False
        db_table = 'django_content_type'
        unique_together = (('app_label', 'model'),)


class DjangoMigrations(models.Model):
    app = models.CharField(max_length=255)
    name = models.CharField(max_length=255)
    applied = models.DateTimeField()

    class Meta:
        managed = False
        db_table = 'django_migrations'


class DjangoSession(models.Model):
    session_key = models.CharField(primary_key=True, max_length=40)
    session_data = models.TextField()
    expire_date = models.DateTimeField()

    class Meta:
        managed = False
        db_table = 'django_session'


class ExamsExam(models.Model):
    name = models.CharField(unique=True, max_length=255)
    slug = models.CharField(unique=True, max_length=255)
    description = models.TextField(blank=True, null=True)
    is_active = models.BooleanField()
    display_order = models.IntegerField()
    created_at = models.DateTimeField()
    updated_at = models.DateTimeField()
    parent_exam = models.ForeignKey('self', models.DO_NOTHING, blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'exams_exam'


class NotificationsNotification(models.Model):
    title = models.CharField(max_length=255)
    message = models.TextField()
    notification_type = models.CharField(max_length=20)
    related_object_type = models.CharField(max_length=50, blank=True, null=True)
    related_object_id = models.IntegerField(blank=True, null=True)
    is_read = models.BooleanField()
    is_sent = models.BooleanField()
    send_email = models.BooleanField()
    send_push = models.BooleanField()
    created_at = models.DateTimeField()
    scheduled_for = models.DateTimeField(blank=True, null=True)
    metadata = models.JSONField(blank=True, null=True)
    user = models.ForeignKey('UsersUser', models.DO_NOTHING)

    class Meta:
        managed = False
        db_table = 'notifications_notification'


class QuestionsMcqchoice(models.Model):
    choice_text = models.TextField()
    is_correct = models.BooleanField()
    display_order = models.IntegerField()
    explanation = models.TextField(blank=True, null=True)
    question = models.ForeignKey('QuestionsQuestion', models.DO_NOTHING)

    class Meta:
        managed = False
        db_table = 'questions_mcqchoice'


class QuestionsQuestion(models.Model):
    text = models.TextField()
    question_type = models.CharField(max_length=20)
    difficulty = models.CharField(max_length=10)
    estimated_time_seconds = models.IntegerField()
    points = models.IntegerField()
    model_answer_text = models.TextField(blank=True, null=True)
    model_calculation_logic = models.JSONField(blank=True, null=True)
    is_active = models.BooleanField()
    answer_explanation = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField()
    updated_at = models.DateTimeField()
    created_by = models.ForeignKey('UsersUser', models.DO_NOTHING, blank=True, null=True)
    last_updated_by = models.ForeignKey('UsersUser', models.DO_NOTHING, related_name='questionsquestion_last_updated_by_set', blank=True, null=True)
    exam = models.ForeignKey(ExamsExam, models.DO_NOTHING)
    topic = models.ForeignKey('QuestionsTopic', models.DO_NOTHING, blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'questions_question'


class QuestionsQuestionTags(models.Model):
    question = models.ForeignKey(QuestionsQuestion, models.DO_NOTHING)
    tag = models.ForeignKey('QuestionsTag', models.DO_NOTHING)

    class Meta:
        managed = False
        db_table = 'questions_question_tags'
        unique_together = (('question', 'tag'),)


class QuestionsTag(models.Model):
    name = models.CharField(unique=True, max_length=100)
    slug = models.CharField(unique=True, max_length=100)
    description = models.TextField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'questions_tag'


class QuestionsTopic(models.Model):
    name = models.CharField(unique=True, max_length=255)
    slug = models.CharField(unique=True, max_length=255)
    description = models.TextField(blank=True, null=True)
    display_order = models.IntegerField()
    is_active = models.BooleanField()
    created_at = models.DateTimeField()
    updated_at = models.DateTimeField()
    parent_topic = models.ForeignKey('self', models.DO_NOTHING, blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'questions_topic'


class SubscriptionsPayment(models.Model):
    amount = models.DecimalField(max_digits=10, decimal_places=5)  # max_digits and decimal_places have been guessed, as this database handles decimal fields as float
    currency = models.CharField(max_length=3)
    status = models.CharField(max_length=20)
    payment_gateway_transaction_id = models.CharField(unique=True, max_length=100)
    payment_method_details = models.JSONField(blank=True, null=True)
    transaction_time = models.DateTimeField()
    billing_address = models.JSONField(blank=True, null=True)
    invoice_number = models.CharField(unique=True, max_length=50, blank=True, null=True)
    refund_reference = models.CharField(max_length=100, blank=True, null=True)
    metadata = models.JSONField(blank=True, null=True)
    user = models.ForeignKey('UsersUser', models.DO_NOTHING)
    user_subscription = models.ForeignKey('SubscriptionsUsersubscription', models.DO_NOTHING, blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'subscriptions_payment'


class SubscriptionsPricingplan(models.Model):
    name = models.CharField(unique=True, max_length=100)
    slug = models.CharField(unique=True, max_length=100)
    description = models.TextField(blank=True, null=True)
    price = models.DecimalField(max_digits=10, decimal_places=5)  # max_digits and decimal_places have been guessed, as this database handles decimal fields as float
    currency = models.CharField(max_length=3)
    billing_cycle = models.CharField(max_length=20)
    features_list = models.JSONField()
    is_active = models.BooleanField()
    display_order = models.IntegerField()
    payment_gateway_plan_id = models.CharField(unique=True, max_length=100, blank=True, null=True)
    trial_days = models.IntegerField()
    created_at = models.DateTimeField()
    updated_at = models.DateTimeField()
    exam = models.ForeignKey(ExamsExam, models.DO_NOTHING)

    class Meta:
        managed = False
        db_table = 'subscriptions_pricingplan'


class SubscriptionsReferralprogram(models.Model):
    name = models.CharField(unique=True, max_length=100)
    description = models.TextField()
    reward_type = models.CharField(max_length=30)
    reward_value = models.DecimalField(max_digits=10, decimal_places=5)  # max_digits and decimal_places have been guessed, as this database handles decimal fields as float
    referrer_reward_type = models.CharField(max_length=30)
    referrer_reward_value = models.DecimalField(max_digits=10, decimal_places=5)  # max_digits and decimal_places have been guessed, as this database handles decimal fields as float
    is_active = models.BooleanField()
    valid_from = models.DateField(blank=True, null=True)
    valid_until = models.DateField(blank=True, null=True)
    usage_limit = models.IntegerField()
    min_purchase_amount = models.DecimalField(max_digits=10, decimal_places=5)  # max_digits and decimal_places have been guessed, as this database handles decimal fields as float
    created_at = models.DateTimeField()
    updated_at = models.DateTimeField()

    class Meta:
        managed = False
        db_table = 'subscriptions_referralprogram'


class SubscriptionsUserreferral(models.Model):
    referral_code_used = models.CharField(max_length=50)
    status = models.CharField(max_length=20)
    reward_granted_to_referrer = models.BooleanField()
    reward_granted_to_referred = models.BooleanField()
    date_referred = models.DateTimeField()
    date_completed = models.DateTimeField(blank=True, null=True)
    referral_program = models.ForeignKey(SubscriptionsReferralprogram, models.DO_NOTHING)
    referred_user = models.OneToOneField('UsersUser', models.DO_NOTHING)
    referrer = models.ForeignKey('UsersUser', models.DO_NOTHING, related_name='subscriptionsuserreferral_referrer_set')
    conversion_subscription = models.ForeignKey('SubscriptionsUsersubscription', models.DO_NOTHING, blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'subscriptions_userreferral'


class SubscriptionsUsersubscription(models.Model):
    start_date = models.DateTimeField()
    end_date = models.DateTimeField(blank=True, null=True)
    status = models.CharField(max_length=20)
    payment_gateway_subscription_id = models.CharField(unique=True, max_length=100, blank=True, null=True)
    auto_renew = models.BooleanField()
    cancelled_at = models.DateTimeField(blank=True, null=True)
    created_at = models.DateTimeField()
    updated_at = models.DateTimeField()
    renewal_reminder_sent = models.BooleanField()
    pricing_plan = models.ForeignKey(SubscriptionsPricingplan, models.DO_NOTHING)
    user = models.ForeignKey('UsersUser', models.DO_NOTHING)

    class Meta:
        managed = False
        db_table = 'subscriptions_usersubscription'


class SupportFaqitem(models.Model):
    question_text = models.TextField()
    answer_text = models.TextField()
    category = models.CharField(max_length=50)
    display_order = models.IntegerField()
    is_published = models.BooleanField()
    created_at = models.DateTimeField()
    updated_at = models.DateTimeField()
    view_count = models.IntegerField()

    class Meta:
        managed = False
        db_table = 'support_faqitem'


class SupportSupportticket(models.Model):
    subject = models.CharField(max_length=255)
    description = models.TextField()
    ticket_type = models.CharField(max_length=20)
    status = models.CharField(max_length=20)
    priority = models.CharField(max_length=10)
    created_at = models.DateTimeField()
    updated_at = models.DateTimeField()
    resolved_at = models.DateTimeField(blank=True, null=True)
    assigned_to = models.ForeignKey('UsersUser', models.DO_NOTHING, blank=True, null=True)
    user = models.ForeignKey('UsersUser', models.DO_NOTHING, related_name='supportsupportticket_user_set', blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'support_supportticket'


class SupportTicketreply(models.Model):
    message = models.TextField()
    is_staff_reply = models.BooleanField()
    created_at = models.DateTimeField()
    ticket = models.ForeignKey(SupportSupportticket, models.DO_NOTHING)
    user = models.ForeignKey('UsersUser', models.DO_NOTHING, blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'support_ticketreply'


class TokenBlacklistBlacklistedtoken(models.Model):
    blacklisted_at = models.DateTimeField()
    token = models.OneToOneField('TokenBlacklistOutstandingtoken', models.DO_NOTHING)

    class Meta:
        managed = False
        db_table = 'token_blacklist_blacklistedtoken'


class TokenBlacklistOutstandingtoken(models.Model):
    token = models.TextField()
    created_at = models.DateTimeField(blank=True, null=True)
    expires_at = models.DateTimeField()
    user = models.ForeignKey('UsersUser', models.DO_NOTHING, blank=True, null=True)
    jti = models.CharField(unique=True, max_length=255)

    class Meta:
        managed = False
        db_table = 'token_blacklist_outstandingtoken'


class UsersUser(models.Model):
    password = models.CharField(max_length=128)
    last_login = models.DateTimeField(blank=True, null=True)
    is_superuser = models.BooleanField()
    username = models.CharField(unique=True, max_length=150)
    first_name = models.CharField(max_length=150)
    last_name = models.CharField(max_length=150)
    email = models.CharField(max_length=254)
    is_staff = models.BooleanField()
    is_active = models.BooleanField()
    date_joined = models.DateTimeField()
    email_verified = models.BooleanField()
    profile_picture_url = models.CharField(max_length=200, blank=True, null=True)
    date_of_birth = models.DateField(blank=True, null=True)
    gdpr_consent_date = models.DateTimeField(blank=True, null=True)
    referral_code = models.CharField(unique=True, max_length=20)
    last_active = models.DateTimeField(blank=True, null=True)
    time_zone = models.CharField(max_length=50)

    class Meta:
        managed = False
        db_table = 'users_user'


class UsersUserGroups(models.Model):
    user = models.ForeignKey(UsersUser, models.DO_NOTHING)
    group = models.ForeignKey(AuthGroup, models.DO_NOTHING)

    class Meta:
        managed = False
        db_table = 'users_user_groups'
        unique_together = (('user', 'group'),)


class UsersUserUserPermissions(models.Model):
    user = models.ForeignKey(UsersUser, models.DO_NOTHING)
    permission = models.ForeignKey(AuthPermission, models.DO_NOTHING)

    class Meta:
        managed = False
        db_table = 'users_user_user_permissions'
        unique_together = (('user', 'permission'),)


class UsersUserpreference(models.Model):
    notification_settings = models.JSONField()
    ui_preferences = models.JSONField(blank=True, null=True)
    created_at = models.DateTimeField()
    updated_at = models.DateTimeField()
    user = models.OneToOneField(UsersUser, models.DO_NOTHING)

    class Meta:
        managed = False
        db_table = 'users_userpreference'
