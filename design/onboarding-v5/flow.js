/* Study Guard onboarding review. Original OneThing references retained for comparison. */
window.ONBOARDING_FLOW = [
  {
    "id": 800,
    "key": "welcome",
    "title": "Welcome",
    "phase": "Value",
    "states": [
      "Welcome"
    ],
    "reference": [
      "800.jpg"
    ],
    "note": "Round 1: “Scroll Less. Study More.” and the original Study Guard mockup video, restored from the earlier onboarding.",
    "revised": true,
    "referenceStale": true
  },
  {
    "id": 813,
    "key": "demo",
    "title": "How earned time works",
    "phase": "Value",
    "states": [
      "Apps locked",
      "Time earned",
      "Time spent"
    ],
    "reference": [
      "813-locked.jpg",
      "813.jpg",
      "813-spent.jpg"
    ],
    "note": "Round 1: Biology (10 correct flashcards → 5 minutes) and Criminal Law (20 correct flashcards → 10 minutes), using the current default of 30 seconds per correct card.",
    "revised": true,
    "referenceStale": true
  },
  {
    "id": 803,
    "key": "studyLevel",
    "title": "Your study level",
    "phase": "Personalize",
    "question": "What are you studying for?",
    "choices": [
      "High school",
      "College / university",
      "Postgraduate",
      "Professional exams"
    ],
    "icons": [
      "🎒",
      "🎓",
      "📚",
      "💼"
    ],
    "states": [
      "Question"
    ],
    "reference": [
      "803.jpg"
    ],
    "note": "Choose your study level. Your exam subject is asked later, immediately before the exam date.",
    "revised": true,
    "referenceStale": true
  },
  {
    "id": 804,
    "key": "pain",
    "title": "Your scrolling concern",
    "phase": "Personalize",
    "question": "What bothers you about your scrolling?",
    "choices": [
      "Time just disappears",
      "I put my own plans off",
      "I stay up later than I want",
      "I'm there, but not really present"
    ],
    "icons": [
      "concern-time",
      "concern-plans",
      "concern-sleep",
      "concern-presence"
    ],
    "states": [
      "Question"
    ],
    "reference": [
      "804.jpg"
    ],
    "note": "All four original answers and the illustrated answer-card layout.",
    "revised": true
  },
  {
    "id": 805,
    "key": "moment",
    "title": "Your scrolling moment",
    "phase": "Personalize",
    "question": "When does a minute turn into an hour?",
    "choices": [
      "First thing in the morning",
      "During work or study",
      "In the gaps in my day",
      "When I get into bed"
    ],
    "states": [
      "Question"
    ],
    "reference": [
      "805.jpg"
    ],
    "note": "Exact question and four options. Selection advances after a short pause, as in OneThing.",
    "revised": true
  },
  {
    "id": 806,
    "key": "generation",
    "title": "Notes to flashcards",
    "phase": "Personalize",
    "states": [
      "Scanning notes",
      "Flashcards ready"
    ],
    "reference": [
      "806.jpg"
    ],
    "note": "An automatic visual demo, inspired by Study Guard’s earlier onboarding: notes scan, cards appear, and an answer flips over. Continue is always available. The animation uses sample content and creates no real deck.",
    "revised": true,
    "referenceStale": true
  },
  {
    "id": 820,
    "key": "subject",
    "title": "Your exam subject",
    "phase": "Personalize",
    "question": "Which subject is your next exam for?",
    "states": [
      "Question"
    ],
    "reference": [],
    "note": "A separate, required subject question immediately before the exam date. Blank or whitespace-only answers cannot continue.",
    "revised": true
  },
  {
    "id": 807,
    "key": "examDate",
    "title": "Your next exam",
    "phase": "Personalize",
    "question": "When is your next exam?",
    "states": [
      "Question"
    ],
    "reference": [
      "807.jpg"
    ],
    "referenceStale": true,
    "note": "Round 1: an exact exam date replaces the habit choices. The selected subject appears above the calendar. Today and future dates are accepted.",
    "revised": true
  },
  {
    "id": 810,
    "key": "baseline",
    "title": "Your starting point",
    "phase": "Time back",
    "question": "How much time do you spend on your phone each day?",
    "choices": [
      "Less than 2 hours",
      "2–4 hours",
      "4–6 hours",
      "6+ hours",
      "I'm not sure"
    ],
    "states": [
      "Question"
    ],
    "reference": [
      "810.jpg"
    ],
    "note": "The five original options. Projections use the same source estimates: 1 / 3 / 5 / 6 hours, or 4 if unsure.",
    "revised": true
  },
  {
    "id": 819,
    "key": "age",
    "title": "Your age",
    "phase": "Time back",
    "question": "How old are you?",
    "choices": [
      "Under 18",
      "18-24",
      "25-34",
      "35-44",
      "45-54",
      "55+"
    ],
    "states": [
      "Question"
    ],
    "reference": [],
    "note": "Latest source addition, missing from the older screenshot board. Uses the same question layout and six age brackets.",
    "revised": true
  },
  {
    "id": 818,
    "key": "examCost",
    "title": "Time before your exam",
    "phase": "Time back",
    "states": [
      "Days until your exam"
    ],
    "reference": [
      "818.jpg"
    ],
    "referenceStale": true,
    "note": "One dot per day until the exam, with scrolling time highlighted—including part of a day. At 3 hours/day for 30 days: 90 hours, or 3.75 days. The hours total is followed by a typed sequence about missed study time. Continue is always available.",
    "revised": true
  },
  {
    "id": 808,
    "key": "empathy",
    "title": "It's not your fault",
    "phase": "Time back",
    "states": [
      "Opening",
      "Headlines",
      "Closing"
    ],
    "reference": [
      "808.jpg",
      "808-headlines.jpg",
      "808-closing.jpg"
    ],
    "note": "Reassurance follows the exam-time calculation, then leads to the method and study-to-scroll rule. The original three tap-through states remain.",
    "revised": true
  },
  {
    "id": 817,
    "key": "method",
    "title": "The method",
    "phase": "Time back",
    "states": [
      "Method"
    ],
    "reference": [
      "817.jpg"
    ],
    "note": "The method now follows “It’s not your fault” and comes before the study-to-scroll rule. The original research copy remains for a later content pass.",
    "revised": true
  },
  {
    "id": 812,
    "key": "studyRule",
    "title": "Your extra study time",
    "phase": "Time back",
    "states": [
      "10 cards · default",
      "5 cards",
      "20 cards"
    ],
    "reference": [
      "time-back.jpg",
      "time-back-zero.jpg"
    ],
    "note": "OneThing’s open dial now emphasizes potential extra study hours before the selected exam. The estimate uses the exam date, reported daily phone time, and 30 seconds per card, with study replacing part of the same phone-time window. The 5 / 10 / 20-card slider updates both the estimate and real five-minute earning rule; 10 is the default. Tap the estimate note for the calculation.",
    "revised": true,
    "referenceStale": true
  },
  {
    "id": 801,
    "key": "moreLife",
    "title": "Study more",
    "phase": "Your plan",
    "states": [
      "Study Guard reviews"
    ],
    "reference": [
      "801.jpg"
    ],
    "note": "Study-focused rotating headlines and icons, with three short, attributed excerpts from Study Guard’s actual App Store reviews. Each card links to its storefront source. The copied OneThing rating and user-count badges are removed.",
    "revised": true
  },
  {
    "id": 814,
    "key": "commitment",
    "title": "A small commitment",
    "phase": "Your plan",
    "states": [
      "Commitment"
    ],
    "reference": [
      "814.jpg"
    ],
    "referenceStale": true,
    "note": "A newly generated transparent Study Guard mascot reaches a fist toward the user. Tap the mascot to commit: a bump, haptic and short celebration lead to plan setup. The oath keeps the selected card count, subject and reward. Reduced Motion uses a brief confirmation.",
    "revised": true
  },
  {
    "id": 815,
    "key": "assembly",
    "title": "Building your plan",
    "phase": "Your plan",
    "states": [
      "Checklist"
    ],
    "reference": [
      "815.jpg"
    ],
    "note": "The checklist summarizes study level, subject, exam date, the selected earning rule, and the study moment.",
    "revised": true,
    "referenceStale": true
  },
  {
    "id": 816,
    "key": "plan",
    "title": "Your next chapter",
    "phase": "Your plan",
    "states": [
      "Make a start",
      "Build a rhythm",
      "Exam day"
    ],
    "reference": [
      "personalized-plan.jpg",
      "personalized-plan-days-4-7.jpg",
      "personalized-plan-finish.jpg"
    ],
    "note": "Three generated illustrations follow the same student and Study Guard mascot from their first deck, through a study-and-unlock routine, to exam day. Tap a chapter or swipe to explore. Subject, exam countdown and selected flashcard rule personalize the story. The floating CTA is available immediately.",
    "revised": true,
    "referenceStale": true
  },
  {
    "id": 506,
    "key": "paywall",
    "title": "Paywall",
    "phase": "Subscribe",
    "states": [
      "Offer"
    ],
    "reference": [
      "paywall.jpg"
    ],
    "note": "Same introductory offer structure, then Study Guard’s existing RevenueCat purchase flow. Its own pricing and trial eligibility apply; the OneThing Superwall offer is preserved alongside as reference.",
    "revised": true
  },
  {
    "id": 601,
    "key": "setup",
    "title": "A little space",
    "phase": "Setup",
    "states": [
      "Introduction"
    ],
    "reference": [
      "601.jpg"
    ],
    "note": "Setup now uses a newly generated transparent reading mascot inside the orbit, with the actual Study Guard app icon at its base. The expanded white card contains its footer and buttons. Study-focused copy replaces the remaining OneThing wording.",
    "revised": true
  },
  {
    "id": 602,
    "key": "permission",
    "title": "Screen Time access",
    "phase": "Setup",
    "states": [
      "Permission"
    ],
    "reference": [
      "602.jpg"
    ],
    "note": "Screen Time introduction with the new reading mascot, app icon, and expanded card containing the access button. The existing iOS authorization flow is unchanged; HTML simulates it.",
    "revised": true
  },
  {
    "id": 606,
    "key": "apps",
    "title": "Choose apps",
    "phase": "Setup",
    "states": [
      "App selection"
    ],
    "reference": [
      "606.jpg"
    ],
    "note": "App selection and its defer action now sit inside the expanded white card. The new reading mascot and app icon continue above it. iOS still owns the real app picker.",
    "revised": true
  },
  {
    "id": 604,
    "key": "notifications",
    "title": "Notifications",
    "phase": "Setup",
    "states": [
      "Reminders"
    ],
    "reference": [
      "604.jpg"
    ],
    "note": "Study Guard’s actual app icon appears in the notification examples and at the orbit base. Study reminders replace OneThing copy. Both Enable notifications and Maybe later are inside the white card; permission and completion behavior is unchanged.",
    "revised": true
  }
];
window.ONBOARDING_DEFAULTS = {studyLevel:1,subject:"Biology",pain:0,moment:3,baseline:1,age:2,studyCards:10};
