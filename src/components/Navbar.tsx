import { Link, useLocation } from 'react-router-dom';
import { Home, LayoutDashboard, MessageSquare, Users, Info, Globe } from 'lucide-react';
import { useLanguage } from '../context/LanguageContext';
import type { Language } from '../translations';

const Navbar = () => {
  const location = useLocation();
  const { t, language, setLanguage } = useLanguage();

  const navItems = [
    { path: '/home', icon: Home, label: t('home') },
    { path: '/dashboard', icon: LayoutDashboard, label: t('dashboard') },
    { path: '/ai-chat', icon: MessageSquare, label: t('aiChat') },
    { path: '/experts', icon: Users, label: t('experts') },
    { path: '/about', icon: Info, label: t('about') },
  ];

  return (
    <nav className="bg-white shadow-md sticky top-0 z-50">
      <div className="container mx-auto px-4">
        <div className="flex items-center justify-between h-16">
          <Link to="/home" className="text-xl font-bold text-primary-700 flex items-center gap-2">
            🌿 {t('appName')}
          </Link>

          <div className="flex items-center gap-2">
            {navItems.map((item) => (
              <Link
                key={item.path}
                to={item.path}
                className={`flex items-center gap-1 px-3 py-2 rounded-lg transition-colors ${
                  location.pathname === item.path
                    ? 'bg-primary-600 text-white'
                    : 'text-gray-600 hover:bg-primary-50'
                }`}
              >
                <item.icon size={18} />
                <span className="hidden md:inline text-sm font-medium">{item.label}</span>
              </Link>
            ))}

            <div className="relative group">
              <button className="flex items-center gap-1 px-3 py-2 rounded-lg hover:bg-primary-50 text-gray-600">
                <Globe size={18} />
                <span className="hidden md:inline text-sm font-medium uppercase">{language}</span>
              </button>
              <div className="absolute right-0 mt-2 w-40 bg-white rounded-lg shadow-xl border border-gray-200 hidden group-hover:block">
                {(['en', 'hi', 'te'] as Language[]).map((lang) => (
                  <button
                    key={lang}
                    onClick={() => setLanguage(lang)}
                    className={`block w-full text-left px-4 py-2 hover:bg-primary-50 ${
                      language === lang ? 'bg-primary-100 font-semibold' : ''
                    }`}
                  >
                    {lang === 'en' && '🇬🇧 English'}
                    {lang === 'hi' && '🇮🇳 हिंदी'}
                    {lang === 'te' && '🇮🇳 తెలుగు'}
                  </button>
                ))}
              </div>
            </div>
          </div>
        </div>
      </div>
    </nav>
  );
};

export default Navbar;