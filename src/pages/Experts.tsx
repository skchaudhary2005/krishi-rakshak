import { motion } from 'framer-motion';
import { Search, Phone, Mail, MapPin } from 'lucide-react';
import { useState } from 'react';
import { useLanguage } from '../context/LanguageContext';
import Navbar from '../components/Navbar';

interface Expert {
  id: number;
  name: string;
  specialty: string;
  location: string;
  phone: string;
  email: string;
}

const mockExperts: Expert[] = [
  {
    id: 1,
    name: "Dr. Rajesh Kumar",
    specialty: "Plant Pathologist",
    location: "Hyderabad, Telangana",
    phone: "+91 98765 43210",
    email: "rajesh.k@agricare.in"
  },
  {
    id: 2,
    name: "Dr. Priya Sharma",
    specialty: "Crop Protection Specialist",
    location: "Mumbai, Maharashtra",
    phone: "+91 98765 43211",
    email: "priya.s@crophealth.in"
  },
  {
    id: 3,
    name: "Ramesh Patel",
    specialty: "Agricultural Extension Officer",
    location: "Pune, Maharashtra",
    phone: "+91 98765 43212",
    email: "ramesh.p@agri.gov.in"
  },
  {
    id: 4,
    name: "Dr. Sunita Reddy",
    specialty: "Organic Farming Expert",
    location: "Bangalore, Karnataka",
    phone: "+91 98765 43213",
    email: "sunita.r@organicfarm.in"
  },
];

const Experts = () => {
  const { t } = useLanguage();
  const [search, setSearch] = useState('');

  const filteredExperts = mockExperts.filter(expert =>
    expert.name.toLowerCase().includes(search.toLowerCase()) ||
    expert.specialty.toLowerCase().includes(search.toLowerCase()) ||
    expert.location.toLowerCase().includes(search.toLowerCase())
  );

  return (
    <div className="min-h-screen">
      <Navbar />
      
      <div className="container mx-auto px-4 py-8 max-w-4xl">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
        >
          <h1 className="text-3xl font-bold text-primary-800 mb-6">
            Agricultural Experts
          </h1>

          <div className="mb-6 relative">
            <Search className="absolute left-4 top-1/2 transform -translate-y-1/2 text-gray-400" size={20} />
            <input
              type="text"
              placeholder={t('searchExperts')}
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="w-full pl-12 pr-4 py-3 rounded-lg border-2 border-primary-200 focus:border-primary-500 outline-none"
            />
          </div>

          <div className="grid gap-4">
            {filteredExperts.map((expert, index) => (
              <motion.div
                key={expert.id}
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: index * 0.1 }}
                className="card hover:shadow-xl transition-shadow"
              >
                <div className="flex items-start justify-between">
                  <div className="flex-1">
                    <h3 className="text-xl font-bold text-gray-800 mb-1">
                      {expert.name}
                    </h3>
                    <p className="text-primary-600 font-semibold mb-3">
                      {expert.specialty}
                    </p>
                    
                    <div className="space-y-2 text-sm text-gray-600">
                      <div className="flex items-center gap-2">
                        <MapPin size={16} className="text-primary-500" />
                        {expert.location}
                      </div>
                      <div className="flex items-center gap-2">
                        <Phone size={16} className="text-primary-500" />
                        <a href={`tel:${expert.phone}`} className="hover:text-primary-700">
                          {expert.phone}
                        </a>
                      </div>
                      <div className="flex items-center gap-2">
                        <Mail size={16} className="text-primary-500" />
                        <a href={`mailto:${expert.email}`} className="hover:text-primary-700">
                          {expert.email}
                        </a>
                      </div>
                    </div>
                  </div>
                  
                  <button className="btn-primary ml-4 py-2 px-4 text-sm">
                    {t('contact')}
                  </button>
                </div>
              </motion.div>
            ))}
          </div>

          {filteredExperts.length === 0 && (
            <div className="text-center py-12 text-gray-500">
              No experts found. Try a different search term.
            </div>
          )}
        </motion.div>
      </div>
    </div>
  );
};

export default Experts;