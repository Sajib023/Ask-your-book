Flutter-based AI RAG Android App that: 

🧠 Runs fully on the user’s phone 

📁 Reads & stores PDFs locally 

🔍 Embeds & searches text locally 

🌐 Uses Groq/OpenRouter API for LLM responses 

❌ No server or cloud storage required












rag_ai_reader/
├── lib/
│   ├── main.dart
│   ├── screens/
│   │   ├── home_screen.dart
│   │   ├── chat_screen.dart
│   │   └── pdf_list_screen.dart
│   ├── services/
│   │   ├── file_service.dart       # Pick & save PDFs
│   │   ├── pdf_parser.dart         # Extract text from PDFs
│   │   ├── embedding_service.dart  # Call embedding API or local embed
│   │   ├── vector_store.dart       # Store & search vectors
│   │   └── llm_service.dart        # Call Groq/OpenRouter
│   ├── models/
│   │   ├── document_model.dart
│   │   └── message_model.dart
│   └── widgets/
│       ├── message_bubble.dart
│       └── loading_indicator.dart
│
├── assets/
│   └── default_prompt.txt
│
├── android/
│   └── (Chaquopy setup, if needed)
│
├── pubspec.yaml
└── README.md
