// Quick test script for Gemini API
import { GoogleGenerativeAI } from '@google/generative-ai';

const API_KEY = 'AIzaSyD7Ft2j9OsjzkMN_g_3feoAh4o1sG1ppBA';
const genAI = new GoogleGenerativeAI(API_KEY);

async function testChat() {
  console.log('Testing Gemini API...');
  
  try {
    const model = genAI.getGenerativeModel({ model: 'gemini-pro' });
    
    const prompt = 'What are the best crops to plant in monsoon season in India? Give a brief answer.';
    
    console.log('Sending prompt:', prompt);
    
    const result = await model.generateContent(prompt);
    const response = await result.response;
    const text = response.text();
    
    console.log('\n✅ API Response:');
    console.log(text);
    console.log('\n✅ API is working correctly!');
    
  } catch (error) {
    console.error('\n❌ API Error:');
    console.error('Message:', error.message);
    console.error('Details:', error);
  }
}

testChat();