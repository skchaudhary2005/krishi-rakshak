import { useState, useRef, useEffect } from 'react';
import { motion } from 'framer-motion';
import { Send, Bot, User, Loader } from 'lucide-react';
import { useLanguage } from '../context/LanguageContext';
import { chatWithAI } from '../services/geminiService';
import type { ChatMessage } from '../services/geminiService';
import Navbar from '../components/Navbar';

const AIChat = () => {
  const { t } = useLanguage();

  const [messages, setMessages] = useState<ChatMessage[]>([
    {
      role: 'assistant',
      content:
        'Namaste! 🙏 I am your AI farming assistant. Ask me anything about crops, diseases, fertilizers, weather, or farming techniques!',
      timestamp: new Date(),
    },
  ]);

  const [input, setInput] = useState('');
  const [loading, setLoading] = useState(false);

  const messagesEndRef = useRef<HTMLDivElement>(null);

  // Scroll to latest message
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({
      behavior: 'smooth',
    });
  }, [messages, loading]);

  // ============================================================
  // SEND MESSAGE
  // ============================================================

  const handleSend = async () => {
    if (!input.trim() || loading) {
      return;
    }

    const messageText = input.trim();

    const userMessage: ChatMessage = {
      role: 'user',
      content: messageText,
      timestamp: new Date(),
    };

    // Show user's message
    setMessages((prev) => [...prev, userMessage]);

    // Clear input
    setInput('');

    // Start loading
    setLoading(true);

    try {
      console.log('📤 Sending message to Gemini...');
      console.log('Question:', messageText);

      const response = await chatWithAI(
        messageText,
        messages
      );

      console.log('✅ Gemini response received');
      console.log('Response:', response);

      const aiMessage: ChatMessage = {
        role: 'assistant',
        content: response,
        timestamp: new Date(),
      };

      setMessages((prev) => [
        ...prev,
        aiMessage,
      ]);

    } catch (error) {
      console.error('❌ Gemini AI Error:', error);

      let errorText =
        'Gemini AI se connection nahi ho pa raha.';

      if (error instanceof Error) {
        errorText = error.message;
      }

      const errorMessage: ChatMessage = {
        role: 'assistant',
        content:
          `⚠️ Gemini AI Error:\n\n${errorText}\n\n` +
          'Please check your Gemini API key and .env file.',
        timestamp: new Date(),
      };

      setMessages((prev) => [
        ...prev,
        errorMessage,
      ]);

    } finally {
      setLoading(false);
    }
  };

  // ============================================================
  // ENTER KEY
  // ============================================================

  const handleKeyPress = (
    e: React.KeyboardEvent<HTMLInputElement>
  ) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();

      if (!loading) {
        handleSend();
      }
    }
  };

  // ============================================================
  // QUICK QUESTIONS
  // ============================================================

  const quickQuestions = [
    'What are the best crops for monsoon season?',
    'How to treat leaf blight?',
    'When should I fertilize my crops?',
    'How to control pests naturally?',
  ];

  // ============================================================
  // UI
  // ============================================================

  return (
    <div className="min-h-screen flex flex-col">

      {/* Navbar */}
      <Navbar />

      <main className="flex-1 container mx-auto px-4 py-6 max-w-4xl flex flex-col">

        {/* ======================================================
            HEADER
        ====================================================== */}

        <motion.div
          initial={{
            opacity: 0,
            y: 20,
          }}
          animate={{
            opacity: 1,
            y: 0,
          }}
          transition={{
            duration: 0.4,
          }}
          className="mb-4"
        >
          <h1 className="text-3xl font-bold text-primary-800 flex items-center gap-2">
            <Bot
              size={32}
              className="text-primary-600"
            />

            {t('chatWithAI')}
          </h1>

          <p className="text-gray-600 mt-2">
            Powered by Google Gemini AI
          </p>
        </motion.div>


        {/* ======================================================
            QUICK QUESTIONS
        ====================================================== */}

        {messages.length === 1 && (
          <motion.div
            initial={{
              opacity: 0,
            }}
            animate={{
              opacity: 1,
            }}
            transition={{
              duration: 0.4,
            }}
            className="mb-4"
          >
            <p className="text-sm text-gray-600 mb-2">
              💡 Quick questions:
            </p>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-2">

              {quickQuestions.map(
                (question, index) => (
                  <motion.button
                    key={index}
                    whileHover={{
                      scale: 1.01,
                    }}
                    whileTap={{
                      scale: 0.98,
                    }}
                    onClick={() =>
                      setInput(question)
                    }
                    className="text-left p-3 bg-primary-50 hover:bg-primary-100 rounded-lg text-sm text-primary-800 transition-colors border border-primary-100"
                  >
                    {question}
                  </motion.button>
                )
              )}

            </div>
          </motion.div>
        )}


        {/* ======================================================
            CHAT BOX
        ====================================================== */}

        <div className="flex-1 bg-white rounded-2xl shadow-lg border border-green-100 p-4 mb-4 overflow-y-auto max-h-[500px]">

          <div className="space-y-4">

            {messages.map(
              (msg, index) => (

                <motion.div
                  key={index}
                  initial={{
                    opacity: 0,
                    y: 10,
                  }}
                  animate={{
                    opacity: 1,
                    y: 0,
                  }}
                  transition={{
                    duration: 0.25,
                  }}
                  className={`flex gap-3 ${
                    msg.role === 'user'
                      ? 'flex-row-reverse'
                      : ''
                  }`}
                >

                  {/* Avatar */}

                  <div
                    className={`flex-shrink-0 w-9 h-9 rounded-full flex items-center justify-center ${
                      msg.role === 'user'
                        ? 'bg-primary-600'
                        : 'bg-green-600'
                    }`}
                  >

                    {msg.role === 'user' ? (
                      <User
                        size={18}
                        className="text-white"
                      />
                    ) : (
                      <Bot
                        size={18}
                        className="text-white"
                      />
                    )}

                  </div>


                  {/* Message content */}

                  <div
                    className={`flex-1 ${
                      msg.role === 'user'
                        ? 'text-right'
                        : 'text-left'
                    }`}
                  >

                    <div
                      className={`inline-block p-3 rounded-xl max-w-[85%] text-left ${
                        msg.role === 'user'
                          ? 'bg-primary-600 text-white'
                          : 'bg-gray-100 text-gray-800'
                      }`}
                    >

                      <p className="whitespace-pre-wrap leading-relaxed">
                        {msg.content}
                      </p>

                    </div>

                    <p className="text-xs text-gray-500 mt-1">
                      {msg.timestamp.toLocaleTimeString()}
                    </p>

                  </div>

                </motion.div>
              )
            )}


            {/* ==================================================
                LOADING
            ================================================== */}

            {loading && (
              <motion.div
                initial={{
                  opacity: 0,
                }}
                animate={{
                  opacity: 1,
                }}
                className="flex gap-3"
              >

                <div className="flex-shrink-0 w-9 h-9 rounded-full bg-green-600 flex items-center justify-center">
                  <Bot
                    size={18}
                    className="text-white"
                  />
                </div>

                <div className="bg-gray-100 p-3 rounded-xl flex items-center gap-2">

                  <Loader
                    size={20}
                    className="animate-spin text-primary-600"
                  />

                  <span className="text-sm text-gray-600">
                    Krishi Rakshak is thinking...
                  </span>

                </div>

              </motion.div>
            )}

            <div ref={messagesEndRef} />

          </div>
        </div>


        {/* ======================================================
            INPUT AREA
        ====================================================== */}

        <div className="bg-white rounded-xl shadow-lg border border-green-100 p-4">

          <div className="flex gap-2">

            <input
              type="text"
              value={input}
              onChange={(e) =>
                setInput(e.target.value)
              }
              onKeyDown={handleKeyPress}
              placeholder={t('askQuestion')}
              className="flex-1 px-4 py-3 border-2 border-primary-200 rounded-lg focus:border-primary-500 focus:ring-2 focus:ring-primary-100 outline-none bg-white"
              disabled={loading}
            />

            <button
              onClick={handleSend}
              disabled={
                !input.trim() || loading
              }
              className={`btn-primary px-6 flex items-center justify-center gap-2 ${
                !input.trim() || loading
                  ? 'opacity-50 cursor-not-allowed'
                  : ''
              }`}
            >

              {loading ? (
                <Loader
                  size={20}
                  className="animate-spin"
                />
              ) : (
                <Send size={20} />
              )}

              <span className="hidden md:inline">
                {loading
                  ? 'Sending...'
                  : t('send')}
              </span>

            </button>

          </div>

        </div>

      </main>

    </div>
  );
};

export default AIChat;