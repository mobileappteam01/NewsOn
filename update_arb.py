import json
import os
import glob

translations = {
    'en': {
        'contactUs': 'Contact Us',
        'getInTouch': 'Get in Touch',
        'contactSupportText': 'For support, inquiries, or feedback regarding our content and platform, please reach out to us. We regularly update our news platform and value your communication.',
        'email': 'Email',
        'phone': 'Phone',
        'website': 'Website'
    },
    'ta': {
        'contactUs': 'எங்களை தொடர்பு கொள்ள',
        'getInTouch': 'தொடர்பில் இருங்கள்',
        'contactSupportText': 'எங்கள் உள்ளடக்கம் மற்றும் தளம் தொடர்பான ஆதரவு, விசாரணைகள் அல்லது பின்னூட்டங்களுக்கு, தயவுசெய்து எங்களை தொடர்பு கொள்ளவும்.',
        'email': 'மின்னஞ்சல்',
        'phone': 'தொலைபேசி',
        'website': 'இணையதளம்'
    },
    'hi': {
        'contactUs': 'संपर्क करें',
        'getInTouch': 'संपर्क में रहें',
        'contactSupportText': 'हमारे सामग्री और प्लेटफ़ॉर्म से संबंधित समर्थन, पूछताछ या फीडबैक के लिए, कृपया हमसे संपर्क करें।',
        'email': 'ईमेल',
        'phone': 'फ़ोन',
        'website': 'वेबसाइट'
    },
    'es': {
        'contactUs': 'Contáctenos',
        'getInTouch': 'Ponerse en contacto',
        'contactSupportText': 'Para soporte, consultas o comentarios sobre nuestro contenido, contáctenos.',
        'email': 'Correo electrónico',
        'phone': 'Teléfono',
        'website': 'Sitio web'
    },
    'fr': {
        'contactUs': 'Contactez-nous',
        'getInTouch': 'Entrer en contact',
        'contactSupportText': 'Pour le support, les demandes ou les commentaires, veuillez nous contacter.',
        'email': 'E-mail',
        'phone': 'Téléphone',
        'website': 'Site Web'
    }
}

for arb_file in glob.glob('lib/l10n/*.arb'):
    lang = os.path.basename(arb_file).split('_')[1].split('.')[0]
    if lang not in translations:
        lang = 'en' # fallback for missing translation in script map

    with open(arb_file, 'r', encoding='utf-8') as f:
        data = json.load(f)

    for key, value in translations[lang].items():
        data[key] = value

    with open(arb_file, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

print("ARB files updated successfully")
