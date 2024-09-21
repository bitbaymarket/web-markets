import gtranslate

langlist={'en-nl': 'Dutch', 'en-no': 'Norwegian', 'en-th': 'Thai', 'en-ne': 'Nepali', 'en-af': 'Afrikaans', 'en-yi': 'Yiddish', 'en-ar': 'Arabic', 'en-jv': 'Javanese', 'en-pt': 'Portuguese', 'en-pl': 'Polish', 'en-id': 'Indonesian', 'en-pa': 'Punjabi', 'en-it': 'Italian', 'en-is': 'Icelandic', 'en-uk': 'Ukrainian', 'en-lv': 'Latvian', 'en-lt': 'Lithuanian', 'en-la': 'Latin', 'en-ga': 'Irish', 'en-ka': 'Georgian', 'en-gl': 'Galician', 'en-gu': 'Gujarati', 'en-kk': 'Kazakh', 'en-vi': 'Vietnamese', 'en-fa': 'Persian', 'en-fi': 'Finnish', 'en-fr': 'French', 'en-uz': 'Uzbek', 'en-ja': 'Japanese', 'en-ur': 'Urdu', 'en-bs': 'Bosnian', 'en-bn': 'Bengali', 'en-be': 'Belarusian', 'en-bg': 'Bulgarian', 'en-el': 'Greek','en': 'English', 'en-eo': 'Esperanto', 'en-ca': 'Catalan', 'en-et': 'Estonian', 'en-eu': 'Basque', 'en-mr': 'Marathi', 'en-ms': 'Malay', 'en-mt': 'Maltese', 'en-tr': 'Turkish', 'en-mg': 'Malagasy', 'en-tg': 'Tajik', 'en-mi': 'Maori', 'en-te': 'Telugu', 'en-mk': 'Macedonian', 'en-ml': 'Malayalam', 'en-mn': 'Mongolian', 'en-es': 'Spanish', 'en-de': 'German','en-da': 'Danish', 'en-ceb': 'Cebuano', 'en-sl': 'Slovenian', 'en-he': 'Hebrew', 'en-si': 'Sinhala', 'en-hi': 'Hindi', 'en-hr': 'Croatian', 'en-hu': 'Hungarian', 'en-sv': 'Swedish', 'en-sw': 'Swahili', 'en-hy': 'Armenian', 'en-su': 'Sundanese', 'en-sr': 'Serbian', 'en-sq': 'Albanian', 'en-ro': 'Romanian', 'en-cy': 'Welsh', 'en-kn': 'Kannada', 'en-ko': 'Korean', 'en-cs': 'Czech', 'en-ru': 'Russian', 'en-ta': 'Tamil', 'en-zh': 'Chinese'}
gcodes={'Turkish': u'tr', 'Swedish': u'sv', 'Icelandic': u'is', 'Estonian': u'et', 'Telugu': u'te', 'Vietnamese': u'vi', 'Marathi': u'mr', 'Javanese': u'jw', 'Slovenian': u'sl', 'Gujarati': u'gu', 'Catalan': u'ca', 'Hindi': u'hi', 'Dutch': u'nl','Russian': u'ru', 'Korean': u'ko', 'Swahili': u'sw', 'Malagasy': u'mg', 'Danish': u'da', 'Indonesian': u'id', 'Latin': u'la', 'Croatian': u'hr', 'Ukrainian': u'uk', 'Welsh': u'cy', 'Bosnian': u'bs', 'Georgian': u'ka', 'Lithuanian': u'lt', 'Malay': u'ms', 'French': u'fr', 'Norwegian': u'no', 'Bengali': u'bn', 'Armenian': u'hy', 'Romanian': u'ro', 'Maltese': u'mt', 'Thai': u'th', 'Afrikaans': u'af','Kazakh': u'kk', 'Albanian': u'sq', 'Cebuano': u'ceb', 'Mongolian': u'mn', 'Nepali': u'ne', 'Finnish': u'fi', 'Uzbek': u'uz', 'Sundanese': u'su', 'Punjabi': u'pa', 'Spanish': u'es', 'Bulgarian': u'bg', 'Greek': u'el', 'Maori': u'mi', 'Latvian': u'lv', 'English': u'en', 'Malayalam': u'ml', 'Serbian': u'sr', 'Esperanto': u'eo', 'Italian': u'it', 'Portuguese': u'pt', 'Irish': u'ga', 'Czech': u'cs','Hungarian': u'hu', 'Chinese': u'zh', 'German': u'de', 'Tamil': u'ta', 'Japanese': u'ja', 'Belarusian': u'be', 'Kannada': u'kn', 'Galician': u'gl', 'Macedonian': u'mk', 'Persian': u'fa', 'Tajik': u'tg', 'Yiddish': u'yi', 'Hebrew': u'iw', 'Basque': u'eu', 'Urdu': u'ur', 'Polish': u'pl', 'Arabic': u'ar', 'Sinhala': u'si'}

def translateInParts(txt, lang):
    global gcodes
    global langlist
    x=0
    txt2=""
    origtxt=txt
    while x != 50:
        res = gtranslate.GoogleTrans().query(txt, lang_to=gcodes[langlist[lang]])
        txt=txt.replace(res[0],'',1)
        txt2+=res[2]
        x+=1
        test=txt.replace(' ','')
        if len(test)==0:
            txt=''
        print "TEXT REMAINING: ", str(len(txt))
        if len(txt)==0:
            break
        if x==50:
            print "Iteration too long"
            float('a')
    print repr(txt2)
    return txt2