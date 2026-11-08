/// Terjemahan bahasa Inggris untuk teks layar AURA, disusun per berkas.
///
/// Kuncinya adalah teks bahasa Indonesia persis seperti di kode. Lihat
/// `strings_en.dart` untuk cara kerjanya.
const englishAppStrings = <String, String>{
  // app_router.dart
  'Halaman tidak ditemukan: {uri}': 'Page not found: {uri}',
  // heat_tier.dart
  'Tombol SOS ditekan': 'SOS button pressed',
  // location_map.dart
  '© OpenStreetMap': '© OpenStreetMap',
  'Peta lokasi anak. Geser atau cubit untuk memperbesar.':
      'Map of your child\'s location. Drag or pinch to zoom.',
  'Buka di Google Maps': 'Open in Google Maps',
  'Perbesar peta': 'Zoom in',
  'Perkecil peta': 'Zoom out',
  'Kembali ke lokasi anak': 'Back to child\'s location',
  // supabase_repository.dart
  'Masuk dulu dengan email atau Facebook.':
      'Sign in with email or Facebook first.',
  'Gagal membuat sesi pengguna.': 'Couldn\'t create a user session.',
  'akun Anda': 'your account',
  'Halaman Facebook tidak bisa dibuka. Pastikan ada browser di ponsel ini, lalu coba lagi.':
      'Couldn\'t open the Facebook page. Make sure this phone has a browser, then try again.',
  'Login {label} belum dinyalakan. Di Supabase, buka Authentication > Sign In / Providers > {label}, nyalakan, lalu isi App ID dan App Secret dari developers.facebook.com.':
      '{label} sign-in is not enabled yet. In Supabase, open Authentication > Sign In / Providers > {label}, turn it on, then fill in the App ID and App Secret from developers.facebook.com.',
  'Email atau akun Facebook ini sudah dipakai akun AURA lain. Keluar dulu, lalu masuk dengan akun tersebut.':
      'This email or Facebook account is already used by another AURA account. Sign out first, then sign in with that account.',
  'Terlalu sering meminta kode. Tunggu sekitar satu menit, lalu coba lagi.':
      'Too many code requests. Wait about a minute, then try again.',
  'Email belum bisa dikirim ke alamat ini. Pengirim email bawaan Supabase hanya mengirim ke anggota tim proyek; sambungkan layanan email (SMTP) di Supabase > Authentication > SMTP.':
      'Email can\'t be sent to this address yet. Supabase\'s built-in sender only emails project team members; connect an email service (SMTP) in Supabase > Authentication > SMTP.',
  'Penyambungan akun belum dinyalakan. Di Supabase, buka Authentication > Sign In / Providers, lalu nyalakan "Manual linking".':
      'Account linking is not enabled yet. In Supabase, open Authentication > Sign In / Providers, then turn on "Manual linking".',
  'Cara masuk ini belum dinyalakan di Supabase (Authentication > Sign In / Providers).':
      'This sign-in method is not enabled in Supabase yet (Authentication > Sign In / Providers).',
  'Alamat email tidak valid. Periksa lagi penulisannya.':
      'Invalid email address. Check the spelling.',
  'Gagal menyimpan bukti setelah beberapa percobaan.':
      'Couldn\'t save the evidence after several attempts.',
  'Perangkat belum ditautkan ke keluarga.':
      'This device is not linked to a family yet.',
  // guardian_brain.dart
  'Halo, {childName}. Aku Aura. Kalau ada yang bikin kamu bingung, takut, atau nggak enak di hati, cerita aja ke aku. Aku nggak akan marah.':
      'Hi, {childName}. I\'m Aura. If anything makes you confused, scared, or upset, just tell me. I won\'t get mad.',
  'Terima kasih sudah berani cerita, {childName}. Yang kamu rasakan itu berat, dan kamu nggak perlu menanggungnya sendirian. Aku mau kamu ngobrol sama orang dewasa yang kamu percaya sekarang. Kalau kamu mau, aku bisa kasih tahu orang tuamu supaya mereka menemani kamu.':
      'Thank you for being brave enough to tell me, {childName}. What you\'re feeling is heavy, and you don\'t have to carry it alone. I\'d like you to talk to an adult you trust right now. If you want, I can let your parents know so they can be with you.',
  'Ini penting, {childName}: kamu tidak salah, dan ini bukan kesalahan kamu. Jangan kirim apa pun lagi dan jangan hapus chat-nya, karena itu bukti. Orang dewasa perlu tahu supaya bisa menghentikan orang ini.':
      'This is important, {childName}: you did nothing wrong, and this is not your fault. Don\'t send anything else and don\'t delete the chat, because it\'s evidence. An adult needs to know so they can stop this person.',
  'Kalau ada yang bilang hal seperti itu tentang tubuhmu dan bikin kamu nggak nyaman, itu bukan salahmu, {childName}. Orang dewasa yang baik tidak bicara begitu ke anak. Kamu boleh tidak membalas.':
      'If someone says things like that about your body and it makes you uncomfortable, it\'s not your fault, {childName}. Good adults don\'t talk to kids like that. You don\'t have to reply.',
  'Judi online itu dibuat supaya pemainnya terus kalah dan ketagihan, {childName}. Banyak orang dewasa pun kehilangan semua uangnya. Kamu nggak perlu ikut, dan kamu nggak akan dimarahi kalau cerita.':
      'Online gambling is designed so players keep losing and get hooked, {childName}. Even many adults lose all their money. You don\'t have to join, and you won\'t get in trouble for telling.',
  'Aku perhatikan orang itu minta kamu merahasiakan sesuatu dari orang tuamu. Orang yang benar-benar baik tidak akan pernah minta begitu. Kamu sudah tepat menceritakannya ke aku.':
      'I noticed that person asked you to keep a secret from your parents. Someone who is truly kind would never ask that. You did the right thing telling me.',
  'Itu menyakitkan, dan kamu nggak pantas diperlakukan begitu. Apa yang mereka tulis tidak menentukan siapa kamu. Jangan dibalas ya, biar kita simpan buktinya dulu.':
      'That hurts, and you don\'t deserve to be treated that way. What they wrote doesn\'t decide who you are. Don\'t reply, okay? Let\'s keep the evidence first.',
  'Kalau ada yang mengancam mau menyakiti kamu, itu serius dan harus ditangani orang dewasa sekarang juga. Jangan temui dia, dan tetap di tempat yang ramai.':
      'If someone threatens to hurt you, that\'s serious and an adult needs to handle it right now. Don\'t meet them, and stay somewhere with other people around.',
  'Ajakan ketemu diam-diam tanpa sepengetahuan orang tua itu tanda bahaya, {childName}. Jangan pergi dulu. Kita beri tahu orang tuamu ya.':
      'Being asked to meet secretly without your parents knowing is a danger sign, {childName}. Don\'t go yet. Let\'s tell your parents, okay?',
  'Jangan kirim uang, pulsa, atau kode apa pun. Kode OTP itu seperti kunci rumah: siapa pun yang memintanya sedang mencoba masuk.':
      'Don\'t send money, phone credit, or any codes. An OTP code is like a house key: anyone asking for it is trying to get in.',
  'Alamat, nama sekolah, dan foto kartu identitas sebaiknya tidak pernah kamu kirim ke orang yang kamu kenal dari internet.':
      'Your address, school name, and ID card photos should never be sent to someone you met on the internet.',
  'Apa pun yang ditawarkan supaya kamu merasa "enak" dari orang seperti itu bisa membahayakan tubuh kamu. Tolak dan ceritakan ke orang dewasa.':
      'Anything someone like that offers to make you "feel good" could harm your body. Say no and tell an adult.',
  'Nggak apa-apa merasa begitu, {childName}. Kamu nggak salah, dan orang yang sayang sama kamu akan lebih ingin membantu daripada marah. Aku tetap di sini kalau kamu siap.':
      'It\'s okay to feel that way, {childName}. You did nothing wrong, and the people who love you would rather help than be angry. I\'m still here when you\'re ready.',
  'Terima kasih sudah berani, {childName}. Orang tuamu sudah diberi tahu lewat AURA, jadi mereka bisa segera membantumu. Sambil menunggu, tetap di tempat yang aman ya.':
      'Thank you for being brave, {childName}. Your parents have been notified through AURA, so they can help you soon. While you wait, stay somewhere safe, okay?',
  'Terima kasih sudah berani, {childName}. Ceritakan ke orang tuamu atau orang dewasa yang kamu percaya sekarang ya. Kalau kamu dalam bahaya, tekan tombol merah di beranda.':
      'Thank you for being brave, {childName}. Tell your parents or an adult you trust right now, okay? If you\'re in danger, press the red button on the home screen.',
  'Aku masih di sini, {childName}. Ceritain pelan-pelan ya, apa yang terjadi?':
      'I\'m still here, {childName}. Take your time and tell me, what happened?',
  // guardian_dialogue.dart
  'Kedengarannya kamu lagi kesal banget. Wajar kok marah. Mau cerita apa yang bikin kamu sekesal ini?':
      'Sounds like you\'re really upset. It\'s okay to be angry. Want to tell me what made you this upset?',
  'Kalau dia terus mengganggu pakai akun baru, itu sudah termasuk pelecehan, {name}. Simpan tangkapan layarnya dan ceritakan ke orang tuamu ya, mereka bisa bantu melaporkan.':
      'If they keep bothering you with new accounts, that counts as harassment, {name}. Save screenshots and tell your parents, okay? They can help report it.',
  'Caranya gampang: buka chat orang itu, ketuk namanya atau tiga titik di pojok, lalu pilih "Blokir". Kalau ada tombol "Laporkan", tekan juga. Jangan hapus chat-nya dulu ya, itu bisa jadi bukti.':
      'It\'s easy: open that person\'s chat, tap their name or the three dots in the corner, then choose "Block". If there\'s a "Report" button, tap that too. Don\'t delete the chat yet, okay? It can be evidence.',
  'Itu pilihan yang bagus. Guru atau wali kelas bisa bantu kamu. Cari waktu saat guru nggak sibuk, lalu bilang kamu mau cerita sesuatu yang penting.':
      'That\'s a good choice. A teacher or homeroom teacher can help you. Find a moment when they\'re not busy, then say you want to tell them something important.',
  'Kamu bisa mulai dengan bilang: "Ma, Pa, aku mau cerita sesuatu, tapi janji dengerin dulu ya." Itu kalimat yang berani banget. Aku yakin kamu bisa, {name}.':
      'You can start by saying: "Mom, Dad, I want to tell you something, but promise to listen first, okay?" That\'s a really brave thing to say. I know you can do it, {name}.',
  'Wajar kalau kamu takut atau malu, {name}. Tapi orang tuamu pasti lebih ingin tahu daripada kamu menanggungnya sendiri. Kamu nggak salah. Mau aku bantu mulai ceritanya?':
      'It\'s normal to feel scared or embarrassed, {name}. But your parents would much rather know than have you carry this alone. You did nothing wrong. Want me to help you start?',
  'Rasa takut itu nggak apa-apa. Kamu bisa cerita ke orang dewasa mana pun yang kamu percaya, nggak harus orang tua: guru, kakak, atau saudara. Siapa yang paling enak diajak bicara?':
      'Feeling scared is okay. You can talk to any adult you trust, not just your parents: a teacher, an older sibling, or a relative. Who\'s the easiest to talk to?',
  'Aku bisa nemenin kamu cerita, kasih tips kalau ada yang ganggu di chat atau game, dan bantu kasih tahu orang tuamu kalau kamu dalam bahaya. Untuk hal penting, tetap cerita juga ke orang dewasa ya, karena mereka bisa bantu langsung.':
      'I can keep you company while you talk, give tips if someone bothers you in chats or games, and help let your parents know if you\'re in danger. For important things, still tell an adult too, because they can help right away.',
  'Ceritamu aman di sini. Aku cuma kasih tahu orang tuamu kalau kamu dalam bahaya, misalnya ada yang mengancam atau minta foto. Selain itu, obrolan kita nggak dikirim ke siapa-siapa.':
      'Your story is safe here. I only tell your parents if you\'re in danger, like if someone threatens you or asks for photos. Other than that, our chats aren\'t sent to anyone.',
  'Aku nggak punya umur kayak manusia. Aku tinggal di HP kamu, di dalam aplikasi AURA ini, dan selalu siap kalau kamu panggil.':
      'I don\'t have an age like humans do. I live in your phone, inside this AURA app, and I\'m always ready when you call me.',
  'Aku Aura, robot penjaga yang tinggal di HP kamu. Tugasku nemenin kamu ngobrol dan bantu kalau ada yang bikin kamu nggak nyaman di internet. Aku bukan manusia, tapi aku dengerin beneran.':
      'I\'m Aura, a guardian robot who lives in your phone. My job is to keep you company and help if something online makes you uncomfortable. I\'m not a human, but I really do listen.',
  'Aku baik, makasih udah nanya! Robot kayak aku nggak pernah capek dengerin cerita. Kamu sendiri gimana hari ini, {name}?':
      'I\'m good, thanks for asking! Robots like me never get tired of listening. How about you today, {name}?',
  'Sama-sama, {name}! Kapan pun kamu butuh, aku ada di sini.':
      'You\'re welcome, {name}! Whenever you need me, I\'m here.',
  'Oke, {name}. Makasih udah ngobrol sama aku. Ingat ya, kalau ada apa-apa, tombol merah di beranda selalu siap. Dadah! 👋':
      'Okay, {name}. Thanks for chatting with me. Remember, if anything happens, the red button on the home screen is always ready. Bye! 👋',
  'Kalau ada yang menyakiti badanmu, itu tidak boleh, siapa pun orangnya, {name}. Kamu berhak aman. Ceritakan ke orang dewasa yang kamu percaya, misalnya guru, atau minta mereka menelepon layanan SAPA 129. Kalau kamu dalam bahaya sekarang, tekan tombol merah di beranda.':
      'If someone hurts your body, that\'s not allowed, no matter who they are, {name}. You deserve to be safe. Tell an adult you trust, like a teacher, or ask them to call the SAPA 129 hotline. If you\'re in danger right now, press the red button on the home screen.',
  'Nggak apa-apa, {name}. Jangan isi password atau data apa pun di halaman itu ya. Bilang ke orang tuamu sekarang supaya kata sandi akunmu bisa segera diganti.':
      'It\'s okay, {name}. Don\'t enter any password or information on that page. Tell your parents now so your account password can be changed right away.',
  'Nggak apa-apa, {name}, kamu tidak salah. Yang salah adalah orang yang meminta. Jangan kirim apa-apa lagi, jangan hapus chat-nya, dan ceritakan ke orang tuamu sekarang ya supaya mereka bisa membantu. Kalau dia mengancam, tekan tombol merah di beranda.':
      'It\'s okay, {name}, you did nothing wrong. The person who asked is the one in the wrong. Don\'t send anything else, don\'t delete the chat, and tell your parents now so they can help. If they threaten you, press the red button on the home screen.',
  'Kalau dia memaksa terus, itu tanda dia bukan orang baik. Kamu boleh berhenti membalas dan langsung blokir. Kamu nggak harus menuruti siapa pun yang bikin kamu nggak nyaman.':
      'If they keep pushing, that\'s a sign they\'re not a good person. You can stop replying and block them right away. You never have to do what someone says when they make you uncomfortable.',
  'Kalau ada yang mengancam kamu, itu serius dan bukan salahmu, {name}. Jangan turuti dan jangan temui dia. Ceritakan ke orang tuamu sekarang, dan kalau kamu merasa dalam bahaya, tekan tombol merah di beranda.':
      'If someone threatens you, that\'s serious and not your fault, {name}. Don\'t do what they say and don\'t meet them. Tell your parents now, and if you feel you\'re in danger, press the red button on the home screen.',
  'Jangan kirim foto ke orang yang kamu kenal dari internet ya, apalagi kalau dia maksa atau minta dirahasiakan. Itu bukan salahmu. Jangan hapus chat-nya, dan ceritakan ke orang tuamu.':
      'Don\'t send photos to someone you met online, okay? Especially if they pressure you or ask you to keep it secret. It\'s not your fault. Don\'t delete the chat, and tell your parents.',
  'Jangan pergi ketemu orang yang kamu kenal dari internet tanpa orang tuamu ya, {name}, walaupun dia kelihatan baik. Orang di internet bisa pura-pura jadi siapa saja.':
      'Don\'t go meet someone you met online without your parents, {name}, even if they seem nice. People online can pretend to be anyone.',
  'Batalkan aja janjinya, nggak apa-apa. Keselamatanmu lebih penting daripada janji. Ceritakan ke orang tuamu supaya mereka tahu, ya.':
      'Just cancel the plan, it\'s okay. Your safety matters more than a promise. Tell your parents so they know, okay?',
  'Alamat rumah, nama sekolah, dan nomor HP itu rahasia, nggak boleh dikasih ke orang yang kamu kenal dari internet. Kalau dia terus nanya, blokir aja dan ceritakan ke orang tuamu.':
      'Your home address, school name, and phone number are private. Never give them to someone you met online. If they keep asking, just block them and tell your parents.',
  'Diejek itu nyakitin, {name}. Kata-kata mereka nggak menentukan siapa kamu. Kalau terjadi di chat, jangan dibalas dan simpan buktinya. Sudah berapa lama begini?':
      'Being teased hurts, {name}. Their words don\'t decide who you are. If it happens in a chat, don\'t reply and save the evidence. How long has this been going on?',
  'Kamu nggak pantas diperlakukan begitu. Coba ceritakan ke orang dewasa yang kamu percaya ya, biar mereka bisa bantu menghentikannya.':
      'You don\'t deserve to be treated like that. Try telling an adult you trust, okay? They can help make it stop.',
  'Makasih udah cerita, {name}. Orang yang nggak kamu kenal di dunia nyata itu nggak selalu jujur soal siapa dia. Dia ngomong apa ke kamu?':
      'Thanks for telling me, {name}. People you don\'t know in real life aren\'t always honest about who they are. What did they say to you?',
  'Kamu boleh banget nggak balas dan langsung blokir. Jangan kasih foto, alamat, atau nama sekolah ya. Mau aku kasih tahu cara blokirnya?':
      'You\'re totally allowed to not reply and just block them. Don\'t share photos, your address, or your school name, okay? Want me to show you how to block?',
  'Pemain yang ngatain itu nggak sportif. Kamu nggak salah. Kamu bisa mute atau blokir dia, dan nggak usah dibalas. Mau tahu caranya?':
      'Players who insult others aren\'t being good sports. You did nothing wrong. You can mute or block them, and you don\'t need to reply. Want to know how?',
  'Waduh, akunmu kenapa? Ingat ya: jangan pernah kasih password atau kode OTP ke siapa pun, termasuk yang ngaku admin game. Minta tolong orang tuamu untuk mengamankan akunnya ya.':
      'Oh no, what happened to your account? Remember: never give your password or OTP code to anyone, including people who claim to be game admins. Ask your parents to help secure the account, okay?',
  'Hati-hati ya, tawaran diamond atau skin gratis sering cuma tipuan buat mencuri akun atau uang. Yang asli cuma dari toko resmi di dalam game. Ada yang nawarin kamu?':
      'Be careful, offers of free diamonds or skins are often just tricks to steal accounts or money. Real ones only come from the official in-game store. Did someone offer you something?',
  'Kalah terus itu nyebelin banget ya, {name}. Kadang istirahat sebentar bikin mainnya lebih fokus lagi. Ada yang bikin kamu kesal pas main?':
      'Losing over and over is so annoying, right, {name}? Sometimes a short break helps you focus again. Did something make you upset while playing?',
  'Seru ya main game! Kamu lagi main apa? Ada yang bikin kamu nggak nyaman pas main?':
      'Games are fun! What are you playing? Has anything made you uncomfortable while playing?',
  'Aku dengerin. Ceritain lebih lanjut dong, kejadiannya gimana?':
      'I\'m listening. Tell me more, what happened?',
  'Main game boleh, asal jangan sampai lupa istirahat dan belajar ya. Ada lagi yang mau kamu ceritain?':
      'Playing games is fine, just don\'t forget to rest and study, okay? Anything else you want to tell me?',
  'Mimpi buruk itu nggak nyata, dan sekarang kamu aman. Nyalakan lampu kecil kalau mau, atau peluk bantal kesayanganmu. Mau ngobrol sebentar biar tenang?':
      'Nightmares aren\'t real, and you\'re safe now. Turn on a small light if you want, or hug your favorite pillow. Want to chat for a bit so you feel calmer?',
  'Nggak apa-apa merasa takut, {name}. Coba tarik napas pelan-pelan bareng aku... tahan sebentar... buang pelan. Apa yang bikin kamu takut?':
      'It\'s okay to feel scared, {name}. Let\'s breathe slowly together... hold it a moment... and breathe out slowly. What\'s making you scared?',
  'Aku tetap di sini. Kalau rasa takutnya karena ada orang yang mengganggu, cerita ke orang dewasa itu langkah paling berani. Kamu mau cerita ke siapa?':
      'I\'m still here. If you\'re scared because someone is bothering you, telling an adult is the bravest step. Who do you want to tell?',
  'Dijauhi teman itu nyakitin banget. Itu bukan karena kamu kurang baik, {name}. Ada satu teman yang masih baik sama kamu?':
      'Being left out by friends really hurts. It\'s not because you\'re not good enough, {name}. Is there one friend who\'s still nice to you?',
  'Merasa sendirian itu nggak enak banget. Tapi sekarang kamu lagi ngobrol sama aku, jadi kamu nggak sendirian. Ada teman atau keluarga yang biasanya enak diajak ngobrol?':
      'Feeling alone is really hard. But right now you\'re chatting with me, so you\'re not alone. Is there a friend or family member who\'s usually easy to talk to?',
  'Aku di sini, {name}. Kedengarannya hatimu lagi berat. Mau cerita pelan-pelan apa yang bikin kamu sedih?':
      'I\'m here, {name}. It sounds like your heart feels heavy. Want to slowly tell me what\'s making you sad?',
  'Makasih udah mau cerita. Sedih itu wajar, dan kamu nggak harus kuat terus. Apa yang biasanya bikin kamu sedikit lebih baik?':
      'Thanks for telling me. Feeling sad is normal, and you don\'t have to be strong all the time. What usually makes you feel a little better?',
  'Kalau sedihnya nggak hilang-hilang beberapa hari, cerita juga ke orang dewasa yang kamu percaya ya. Mereka bisa bantu lebih banyak dari aku.':
      'If the sadness doesn\'t go away for a few days, tell an adult you trust too, okay? They can help more than I can.',
  'Kalau lagi marah, coba hitung pelan sampai sepuluh atau minum air dulu. Setelah agak tenang, kita pikirin bareng ya.':
      'When you\'re angry, try counting slowly to ten or drinking some water first. Once you\'re a bit calmer, we can think it through together.',
  'Nilai jelek bukan berarti kamu bodoh, {name}. Itu cuma tanda bagian mana yang perlu dilatih lagi. Kamu bisa minta bantuan guru atau orang tua untuk belajar bareng.':
      'A bad grade doesn\'t mean you\'re not smart, {name}. It just shows which part needs more practice. You can ask a teacher or your parents to study with you.',
  'Tugas dan ujian memang bisa bikin pusing. Coba kerjakan sedikit demi sedikit, mulai dari yang paling gampang, lalu istirahat sebentar. Pelajaran apa yang paling bikin susah?':
      'Homework and tests can be stressful. Try doing a little at a time, starting with the easiest part, then take a short break. Which subject is the hardest?',
  'Kalau ada masalah dengan guru dan menurutmu nggak adil, kamu boleh cerita ke orang tuamu supaya mereka bisa bicara baik-baik dengan gurunya.':
      'If you have a problem with a teacher and you think it\'s unfair, you can tell your parents so they can talk to the teacher calmly.',
  'Gimana sekolahmu hari ini, {name}? Ada yang seru, atau ada yang bikin nggak nyaman?':
      'How was school today, {name}? Anything fun, or anything that made you uncomfortable?',
  'Berantem sama teman memang bikin nggak enak hati. Biasanya setelah sama-sama tenang, ngobrol baik-baik bisa membantu. Kalian berantem soal apa?':
      'Fighting with a friend feels bad. Usually, once you both calm down, talking it over nicely helps. What did you fight about?',
  'Cerita soal temanmu dong. Kalian biasanya main apa?':
      'Tell me about your friends! What do you usually play together?',
  'Teman yang baik itu yang bikin kamu nyaman jadi diri sendiri. Temanmu seperti itu?':
      'A good friend is someone who makes you comfortable being yourself. Is your friend like that?',
  'Dimarahi itu bikin sedih ya. Biasanya orang tua marah karena khawatir, bukan karena nggak sayang. Mau cerita kenapa kamu dimarahi?':
      'Getting scolded feels sad, right? Usually parents get angry because they\'re worried, not because they don\'t love you. Want to tell me why you were scolded?',
  'Kalau orang di rumah lagi bertengkar, itu bukan salah kamu, {name}. Kamu boleh cari tempat yang tenang dan cerita ke orang dewasa lain yang kamu percaya.':
      'If people at home are arguing, it\'s not your fault, {name}. You can find a quiet place and talk to another adult you trust.',
  'Gimana keadaan di rumah, {name}? Kamu nyaman di rumah?':
      'How are things at home, {name}? Do you feel comfortable at home?',
  'Lagi gabut ya? Mau tebak-tebakan sama aku? Atau coba ini: gambar robot kayak aku, atau main di luar sebentar kalau cuacanya cerah 😄':
      'Bored? Want to play riddles with me? Or try this: draw a robot like me, or play outside for a bit if the weather\'s nice 😄',
  'Ide lain: bikin cerita pendek tentang petualangan robot, bantu orang di rumah, atau baca buku yang kamu suka. Mana yang seru?':
      'Other ideas: write a short story about a robot adventure, help someone at home, or read a book you like. Which sounds fun?',
  'Kamu kedengarannya capek. Istirahat dulu nggak apa-apa kok. Kamu udah minum air dan makan belum?':
      'You sound tired. It\'s okay to rest first. Have you had some water and something to eat?',
  'Wah, ikut senang dengarnya, {name}! 🎉 Cerita dong, apa yang bikin kamu senang?':
      'Yay, I\'m happy to hear that, {name}! 🎉 Tell me, what made you happy?',
  'Keren! Kamu pantas bangga sama dirimu sendiri. Cerita juga ke orang tuamu ya, pasti mereka ikut senang.':
      'Awesome! You should be proud of yourself. Tell your parents too, they\'ll be happy for you.',
  'Semoga cepat sembuh ya, {name}. Bilang ke orang tuamu atau orang dewasa di dekatmu kalau badanmu nggak enak, supaya bisa diperiksa. Aku nggak bisa kasih obat, tapi aku bisa nemenin ngobrol.':
      'Get well soon, {name}. Tell your parents or an adult nearby if you don\'t feel well, so they can check on you. I can\'t give medicine, but I can keep you company.',
  'Hihi, suka sama seseorang itu wajar kok 😊. Yang penting, kalau dia orang yang kamu kenal dari internet lalu minta foto atau ngajak ketemu diam-diam, itu tanda bahaya ya. Dia teman sekolahmu?':
      'Hehe, having a crush is totally normal 😊. Just remember, if it\'s someone you met online who asks for photos or wants to meet secretly, that\'s a danger sign. Is it someone from your school?',
  'Itu cara yang bagus buat menenangkan diri. Coba lakukan sebentar ya, nanti cerita lagi sama aku kalau mau.':
      'That\'s a great way to calm down. Try it for a bit, and tell me more later if you want.',
  'Ceritain aja, {name}. Aku dengerin dari awal sampai akhir, dan aku nggak akan marah. Ini soal apa?':
      'Just tell me, {name}. I\'ll listen from start to finish, and I won\'t get mad. What\'s it about?',
  'Syukurlah! Kalau nanti ada yang mau diceritain, aku di sini. Mau tebak-tebakan dulu?':
      'Glad to hear it! If there\'s ever something you want to talk about, I\'m here. Want to play riddles first?',
  'Selamat pagi, {name}! ☀️ Semoga harimu menyenangkan.':
      'Good morning, {name}! ☀️ Hope you have a great day.',
  'Selamat malam, {name}. 🌙 Belum tidur?':
      'Good evening, {name}. 🌙 Not asleep yet?',
  'Waalaikumsalam, {name}! 😊': 'Wa alaikum salam, {name}! 😊',
  'Hai, {name}! Senang kamu mampir.': 'Hi, {name}! Glad you stopped by.',
  'Hai lagi, {name}!': 'Hi again, {name}!',
  'Tebak-tebakan ya! Ikan apa yang bisa terbang? ... Lele-lawar! 🦇😄':
      'Riddle time! What do you call a fish with no eyes? ... A fsh! 🐟😄',
  'Kenapa matahari tenggelam? ... Karena nggak bisa berenang! ☀️😄':
      'Why did the sun go to school? ... To get brighter! ☀️😄',
  'Sayur apa yang paling dingin? ... Kembang kol, soalnya "cold"! 🥦😄':
      'What\'s the coolest vegetable? ... A chilly pepper! 🌶️😄',
  'Hewan apa yang paling kuat? ... Kuda, soalnya bisa angkat kaki! 🐴😄':
      'Why are horses so strong? ... Because they never skip leg day! 🐴😄',
  'Kalau sudah sering terjadi, kamu perlu bantuan orang dewasa secepatnya, {name}. Cerita ke guru atau orang dewasa yang kamu percaya, atau minta mereka menelepon SAPA 129. Kamu tidak sendirian.':
      'If it\'s been happening a lot, you need an adult\'s help as soon as possible, {name}. Tell a teacher or an adult you trust, or ask them to call SAPA 129. You\'re not alone.',
  'Kalau sudah lama, itu bukan hal kecil lagi, {name}. Kamu sudah bertahan sendirian cukup lama. Saatnya minta bantuan orang dewasa supaya ini berhenti.':
      'If it\'s been going on for a long time, it\'s not a small thing anymore, {name}. You\'ve handled it alone for long enough. It\'s time to ask an adult for help so it stops.',
  'Bagus kamu cerita dari awal, {name}. Jangan dibalas, simpan buktinya, dan kalau terulang, ceritakan ke orang dewasa ya.':
      'Good thing you told me early, {name}. Don\'t reply, save the evidence, and if it happens again, tell an adult, okay?',
  'Kamu berani banget, {name}. Tunjukkan chat atau ceritakan kejadiannya ke orang tuamu atau guru ya. Aku tetap di sini kalau kamu mau cerita lagi.':
      'You\'re really brave, {name}. Show the chat or tell your parents or a teacher what happened, okay? I\'m still here if you want to talk more.',
  'Nggak apa-apa. Yang penting jangan balas dan jangan kirim apa pun ke orang itu ya. Kalau nanti kamu siap cerita, aku ada di sini.':
      'It\'s okay. The important thing is don\'t reply and don\'t send anything to that person, okay? When you\'re ready to talk, I\'m here.',
  'Nggak apa-apa kalau masih bingung. Coba ceritakan pelan-pelan, orang itu ngomong apa ke kamu?':
      'It\'s okay if you\'re still confused. Try telling me slowly, what did that person say to you?',
  'Yuk minum air dan makan dulu ya, {name}. Badan yang segar bikin pikiran juga lebih tenang. Nanti cerita lagi sama aku.':
      'Let\'s drink some water and eat first, okay, {name}? A refreshed body helps your mind feel calmer too. Tell me more later.',
  'Oke, ceritain aja, {name}. Aku dengerin.':
      'Okay, go ahead, {name}. I\'m listening.',
  'Nggak apa-apa. Kalau nanti ada yang mau kamu ceritain, aku tetap di sini ya.':
      'It\'s okay. If there\'s something you want to tell me later, I\'m still here.',
  'Nggak apa-apa kalau belum tahu. Kita pelan-pelan aja. Coba ceritain apa yang terjadi hari ini?':
      'It\'s okay if you don\'t know yet. Let\'s take it slow. Can you tell me what happened today?',
  'Oke, nggak apa-apa. Kalau ada yang mau kamu ceritain, aku di sini ya, {name}.':
      'Okay, that\'s fine. If there\'s something you want to talk about, I\'m here, {name}.',
  'Aku dengerin kok, {name}. Mau cerita soal apa?':
      'I\'m listening, {name}. What do you want to talk about?',
  'Aku dengerin kok. Boleh ceritain lebih detail biar aku ngerti?':
      'I\'m listening. Can you tell me more details so I understand?',
  'Hmm, aku belum terlalu ngerti. Ini soal sekolah, teman, game, atau yang lain?':
      'Hmm, I don\'t quite understand yet. Is this about school, friends, games, or something else?',
  'Maaf ya, aku robot jadi kadang kurang paham. Coba ceritain pakai kata-kata lain?':
      'Sorry, I\'m a robot so sometimes I don\'t get it. Could you say it in other words?',
  // parent_account_step.dart
  'Lanjutkan dengan Facebook': 'Continue with Facebook',
  'atau dengan email': 'or with email',
  'Email Anda': 'Your email',
  'nama@gmail.com': 'name@gmail.com',
  'Kirim kode ke email': 'Send code to email',
  'Kode masuk dikirim ke ': 'Sign-in code sent to ',
  '. Tidak ada di kotak masuk? Cek folder ': '. Not in your inbox? Check your ',
  'Spam': 'Spam',
  'Kode dari email': 'Code from email',
  // secure_account_page.dart
  'Amankan Akun': 'Secure Account',
  'Supaya data tidak hilang': 'So your data isn\'t lost',
  'Sambungkan akun ini ke email atau Facebook. Data anak, peringatan, dan bukti tetap sama. Setelah ini, kalau aplikasi dihapus atau HP diganti, Anda cukup masuk lagi dengan email atau Facebook yang sama.':
      'Link this account to email or Facebook. Your child\'s data, alerts, and evidence stay the same. After this, if the app is deleted or you change phones, just sign in again with the same email or Facebook.',
  'Akun sudah aman': 'Account is secure',
  'Akun ini sudah tersambung.': 'This account is already linked.',
  'Akun ini sudah tersambung ke {account}. Masuk lagi dengan akun itu kapan pun, dan semua data kembali.':
      'This account is linked to {account}. Sign in with that account anytime, and all your data comes back.',
  // sign_in_page.dart
  'Masuk': 'Sign in',
  'Masuk atau daftar': 'Sign in or sign up',
  'Pakai email atau Facebook supaya akun Anda aman. Ganti HP atau pasang ulang aplikasi? Masuk lagi dengan akun yang sama, dan semua data tetap ada.':
      'Use email or Facebook to keep your account safe. Changing phones or reinstalling the app? Sign in again with the same account, and all your data is still there.',
  'Membuka akun Anda...': 'Opening your account...',
  'Isi nama dan nomor HP Anda. Nomor ini yang ditelepon saat anak menekan tombol darurat.':
      'Enter your name and phone number. This number is called when your child presses the emergency button.',
  'Daftarkan Anak': 'Register Child',
  'Masuk sebagai Orang Tua': 'Sign in as Parent',
  'Ponsel ini akan dilindungi AURA': 'This phone will be protected by AURA',
  'Anak akan diminta menyetujui perlindungan ini di langkah berikutnya. Tanpa persetujuan, pemindaian tidak berjalan.':
      'Your child will be asked to agree to this protection in the next step. Without consent, scanning doesn\'t run.',
  'Nama anak': 'Child\'s name',
  'Nama Anda': 'Your name',
  'Ayu': 'Ayu',
  'Nomor HP Anda': 'Your phone number',
  'Ditelepon otomatis saat anak menekan tombol darurat.':
      'Called automatically when your child presses the emergency button.',
  'Usia hanya boleh berisi angka.': 'Age can only contain digits.',
  'Usia anak': 'Child\'s age',
  'Isi usia dengan angka': 'Enter the age as a number',
  'AURA ditujukan untuk anak usia 3-17 tahun':
      'AURA is meant for children aged 3-17',
  'Lanjut': 'Continue',
  'Masuk sebagai {account}': 'Signed in as {account}',
  'Ganti akun': 'Switch account',
  // child_consent_page.dart
  'Satu langkah lagi': 'One more step',
  'Memeriksa tanda bahaya di pesan yang masuk':
      'Checks incoming messages for danger signs',
  'AURA membaca notifikasi pesan dari WhatsApp, Instagram, TikTok, Telegram, SMS, chat game Roblox, dan aplikasi chat lain, lalu mencari tanda bahaya seperti ancaman, ajakan bertemu diam-diam, atau permintaan foto. Pemeriksaannya terjadi di ponselmu sendiri; obrolan biasa tidak dikirim ke siapa pun.':
      'AURA reads message notifications from WhatsApp, Instagram, TikTok, Telegram, SMS, Roblox game chat, and other chat apps, then looks for danger signs like threats, invitations to meet secretly, or requests for photos. The checking happens on your own phone; normal chats are not sent to anyone.',
  'Memberi tahu orang tuamu kalau ada bahaya':
      'Tells your parents if there is danger',
  'Yang dikirim adalah jenis bahayanya dan potongan kecil pesan pemicunya, bukan seluruh isi chat kamu.':
      'What gets sent is the type of danger and a small piece of the message that triggered it, not your whole chat.',
  'Mengirim lokasimu kalau kamu menekan tombol darurat':
      'Sends your location when you press the emergency button',
  'Setiap AURA dibuka, kamu diminta menyalakan GPS supaya lokasimu siap kalau darurat. Lokasi tetap hanya dikirim saat kamu sendiri yang menekan tombol itu.':
      'Every time AURA opens, you are asked to turn on GPS so your location is ready in an emergency. Your location is still only sent when you press that button yourself.',
  'Menelepon orang tuamu kalau kamu menekan tombol darurat':
      'Calls your parents when you press the emergency button',
  'Supaya orang tuamu bisa langsung bicara denganmu. Tetap jalan walau internet sedang mati. Kalau ponselmu tidak punya pulsa, kamu juga bisa menelepon lewat WhatsApp; untuk itu AURA menyimpan nomor orang tuamu di Kontak kalau belum ada. Kontak lain tidak diubah, dibaca, atau dikirim ke mana pun.':
      'So your parents can talk to you right away. It still works when the internet is down. If your phone has no call credit, you can also call through WhatsApp; for that, AURA saves your parent\'s number in Contacts if it isn\'t there yet. Other contacts are never changed, read, or sent anywhere.',
  'Membalas obrolanmu dengan Aura memakai AI':
      'Answers your chats with Aura using AI',
  'Pesan yang kamu tulis ke Aura dikirim ke layanan AI supaya Aura bisa menjawab, dan tidak dipakai untuk melatih AI. Pesan yang berbahaya tidak dikirim ke sana; orang tuamu yang diberi tahu.':
      'Messages you write to Aura are sent to an AI service so Aura can reply, and they aren\'t used to train the AI. Dangerous messages are not sent there; your parents are notified instead.',
  'Tidak merekam diam-diam': 'Doesn\'t record secretly',
  'AURA tidak pernah menyalakan kamera atau mikrofon tanpa kamu tahu.':
      'AURA never turns on the camera or microphone without you knowing.',
  'Tidak membaca semua obrolanmu': 'Doesn\'t read all your chats',
  'Obrolan yang tidak mengandung tanda bahaya tidak dikirim ke mana pun.':
      'Chats without danger signs aren\'t sent anywhere.',
  'Tidak menyembunyikan dirinya': 'Doesn\'t hide itself',
  'Ikon AURA selalu terlihat di ponselmu, dan kamu bisa membuka riwayat apa saja yang pernah dikirim ke orang tuamu.':
      'The AURA icon is always visible on your phone, and you can open the history of everything that was ever sent to your parents.',
  'Supaya AURA bisa memeriksa pesan yang masuk, nyalakan "Akses notifikasi" untuk AURA di halaman berikutnya.':
      'So AURA can check incoming messages, turn on "Notification access" for AURA on the next page.',
  'Nanti': 'Later',
  'Buka': 'Open',
  'Kesepakatan Kita': 'Our Agreement',
  'Apa yang AURA lakukan di ponsel ini': 'What AURA does on this phone',
  'Baca pelan-pelan ya. Kalau ada yang kamu tidak setujui, kamu boleh bertanya ke orang tuamu dulu.':
      'Read it slowly, okay? If there\'s anything you don\'t agree with, you can ask your parents first.',
  'Yang AURA lakukan': 'What AURA does',
  'Yang AURA tidak lakukan': 'What AURA doesn\'t do',
  'Kalau nanti kamu merasa AURA keliru atau kamu tidak nyaman, bilang ke orang tuamu. Kamu juga bisa melihat sendiri semua peringatan yang pernah dikirim.':
      'If you ever feel AURA got it wrong or you\'re uncomfortable, tell your parents. You can also see every alert that was ever sent yourself.',
  'Aku sudah baca dan mengerti': 'I\'ve read and understood',
  'Nanti dulu': 'Not now',
  'Aku setuju': 'I agree',
  // child_home_page.dart
  'AURA!': 'AURA!',
  'Pusat bantuan': 'Help center',
  'Mengirim SOS...': 'Sending SOS...',
  'Orang tuamu segera tahu': 'Your parents will know soon',
  'Batalkan': 'Cancel',
  'SOS terkirim dalam {secondsLeft} detik':
      'SOS sends in {secondsLeft} seconds',
  'Panic Orb': 'Panic Orb',
  'Tekan sekali untuk SOS': 'Press once for SOS',
  'Batalkan SOS': 'Cancel SOS',
  'Lokasimu belum terkirim karena internet sedang tidak tersambung. Sebutkan kamu di mana saat orang tuamu mengangkat telepon.':
      'Your location wasn\'t sent because the internet isn\'t connected. Tell your parents where you are when they answer the call.',
  'Lokasi terakhirmu ikut terkirim. Kalau kamu sudah pindah, beri tahu orang tuamu kamu di mana.':
      'Your last known location was sent too. If you\'ve moved, tell your parents where you are.',
  'Lokasimu ikut terkirim.': 'Your location was sent too.',
  'Lokasimu belum terkirim karena GPS di ponsel sedang mati.':
      'Your location wasn\'t sent because GPS is off on this phone.',
  'Lokasimu belum terkirim karena izin lokasi belum dinyalakan.':
      'Your location wasn\'t sent because location permission isn\'t turned on.',
  'Lokasimu belum terkirim karena sinyal GPS belum didapat.':
      'Your location wasn\'t sent because there\'s no GPS signal yet.',
  '{reason} Kalau bisa, kabari orang tuamu kamu di mana.':
      '{reason} If you can, tell your parents where you are.',
  'Kami sudah menelepon orang tuamu.': 'We\'ve called your parents.',
  'Nomor orang tuamu sudah disiapkan di aplikasi Telepon. Tekan tombol panggil hijau kalau belum.':
      'Your parent\'s number is ready in the Phone app. Press the green call button if you haven\'t yet.',
  'Nomor HP orang tuamu belum diisi, jadi kami belum bisa menelepon. Minta orang tuamu mengisinya di aplikasi AURA mereka.':
      'Your parent\'s phone number isn\'t set yet, so we can\'t call. Ask your parents to add it in their AURA app.',
  'Ponsel ini tidak bisa menelepon. Kalau bisa, minta tolong orang dewasa di dekatmu.':
      'This phone can\'t make calls. If you can, ask an adult nearby for help.',
  'Ponsel ini tidak bisa menelepon biasa. Coba telepon orang tuamu lewat WhatsApp di bawah.':
      'This phone can\'t make regular calls. Try calling your parents through WhatsApp below.',
  'Kami mencoba menelepon orang tuamu lewat WhatsApp, tapi internet sepertinya sedang tidak tersambung. Kalau panggilannya tidak masuk, minta tolong orang dewasa di dekatmu.':
      'We tried to call your parents through WhatsApp, but the internet doesn\'t seem to be connected. If the call doesn\'t go through, ask an adult nearby for help.',
  'Kami sudah menelepon orang tuamu lewat WhatsApp.':
      'We\'ve called your parents through WhatsApp.',
  'Chat WhatsApp orang tuamu sudah dibuka. Tekan ikon telepon di pojok kanan atas untuk menelepon.':
      'Your parent\'s WhatsApp chat is open. Tap the phone icon in the top right corner to call.',
  'WhatsApp tidak bisa dibuka. Coba telepon biasa, atau minta tolong orang dewasa di dekatmu.':
      'WhatsApp couldn\'t be opened. Try a regular call, or ask an adult nearby for help.',
  'Telepon lewat WhatsApp': 'Call through WhatsApp',
  // settings_page.dart: kesiapan telepon WhatsApp
  'Orang Tua (AURA)': 'Parent (AURA)',
  'Telepon WhatsApp': 'WhatsApp calls',
  'Siap, langsung menelepon': 'Ready, calls right away',
  'Saat SOS, tombol WhatsApp baru membuka chat. Siapkan supaya langsung menelepon.':
      'During an SOS, the WhatsApp button only opens the chat. Set it up so it calls right away.',
  'Nomor orang tuamu sudah ada di Kontak. Buka WhatsApp sekali supaya nomornya dikenali, lalu kembali ke sini.':
      'Your parent\'s number is in Contacts now. Open WhatsApp once so it recognises the number, then come back here.',
  'Izin Kontak dibutuhkan supaya WhatsApp bisa langsung menelepon orang tuamu.':
      'Contacts permission is needed so WhatsApp can call your parents right away.',
  'Periksa lagi': 'Check again',
  'Siapkan': 'Set up',
  'Pesan daruratmu terkirim': 'Your emergency message was sent',
  'Peringatan belum terkirim': 'The alert hasn\'t been sent yet',
  'Orang tuamu sudah menerima peringatanmu. Tetap di tempat yang ramai dan terang kalau bisa.':
      'Your parents received your alert. Stay somewhere busy and well-lit if you can.',
  'Internet sedang tidak tersambung, jadi peringatan belum sampai. Tetap di tempat yang ramai dan terang kalau bisa.':
      'The internet isn\'t connected, so the alert hasn\'t arrived yet. Stay somewhere busy and well-lit if you can.',
  'Telepon orang tua lagi': 'Call parents again',
  'Oke': 'Okay',
  // child_pairing_page.dart
  'Teman': 'Friend',
  'Halo, {name}': 'Hi, {name}',
  'Minta kode dari ponsel orang tuamu, lalu ketik di sini supaya kita bisa terhubung.':
      'Ask for the code from your parent\'s phone, then type it here so we can connect.',
  'Hubungkan': 'Connect',
  'Orang tuamu bisa melihat kodenya di aplikasi AURA mereka, pada menu "Tautkan".':
      'Your parents can see the code in their AURA app, in the "Link" menu.',
  // child_shell.dart
  'Satu hal dulu sebelum mulai': 'One thing before we start',
  'Kami perlu menjelaskan apa yang AURA lakukan di ponsel ini, dan meminta persetujuanmu.':
      'We need to explain what AURA does on this phone and ask for your consent.',
  'Baca dan putuskan': 'Read and decide',
  // guardian_chat_page.dart
  'Aura': 'Aura',
  'Aku ada masalah di game': 'I have a problem in a game',
  'Ada yang chat aneh...': 'Someone sent a weird chat...',
  'Aku merasa takut...': 'I feel scared...',
  'Ceritain aja, aku disini kok!': 'Just tell me, I\'m here!',
  'Halo! Saya Aura': 'Hi! I\'m Aura',
  'Ada yang bisa aku bantuin?\nKamu lagi ngerasa apa hari ini?':
      'How can I help?\nHow are you feeling today?',
  'Orang tuamu diberi tahu soal ini': 'Your parents were told about this',
  'Aura sedang mengetik...': 'Aura is typing...',
  'Ketik pesan...': 'Type a message...',
  'Kirim pesan': 'Send message',
  'Aura dibantu AI. Jangan bagikan data pribadi. Orang tuamu hanya diberi tahu kalau kamu dalam bahaya.':
      'Aura is helped by AI. Don\'t share personal information. Your parents are only told if you\'re in danger.',
  'Ceritamu aman. Orang tuamu hanya diberi tahu kalau kamu dalam bahaya.':
      'Your story is safe. Your parents are only told if you\'re in danger.',
  // help_sheet.dart
  'Butuh bantuan?': 'Need help?',
  'Nggak harus darurat. Pilih yang paling cocok buatmu.':
      'It doesn\'t have to be an emergency. Pick what fits you best.',
  'Ngobrol dengan Aura': 'Chat with Aura',
  'Ceritain apa yang bikin kamu nggak nyaman.':
      'Tell me what makes you uncomfortable.',
  'Laporkan chat aneh': 'Report a weird chat',
  'Salin pesannya ke sini, nanti Aura periksa.':
      'Copy the message here, and Aura will check it.',
  'Lihat apa yang dikirim ke orang tuamu, atau keluar.':
      'See what was sent to your parents, or sign out.',
  // intervention_sheet.dart
  'Peringatan Dini': 'Early Warning',
  'Orang tuamu sudah diberi tahu supaya bisa membantu. Kamu tidak sedang dalam masalah.':
      'Your parents have been told so they can help. You\'re not in trouble.',
  'Saya mengerti': 'I understand',
  'Orang ini memakai cara yang sering dipakai pelaku untuk mendekati anak.':
      'This person is using tricks that predators often use to approach children.',
  'Jangan kirim foto apa pun. Ini bukan salahmu, dan kamu tidak sendirian.':
      'Don\'t send any photos. This is not your fault, and you\'re not alone.',
  'Komentar soal tubuhmu yang bikin nggak nyaman itu salah mereka, bukan kamu.':
      'Comments about your body that make you uncomfortable are their fault, not yours.',
  'Judi online dibuat supaya pemainnya kalah. Kamu tidak perlu ikut.':
      'Online gambling is designed so players lose. You don\'t have to join.',
  'Apa yang mereka katakan tidak benar dan tidak menggambarkan dirimu.':
      'What they\'re saying isn\'t true and doesn\'t describe who you are.',
  'Ada ancaman kekerasan di sini. Ini harus ditangani orang dewasa.':
      'There is a threat of violence here. An adult needs to handle this.',
  'Yang kamu rasakan berat sekali, dan kamu berhak dibantu.':
      'What you\'re feeling is really heavy, and you deserve help.',
  'Ajakan ketemu diam-diam adalah tanda bahaya yang serius.':
      'An invitation to meet secretly is a serious danger sign.',
  'Jangan kirim uang, pulsa, atau kode apa pun ke orang ini.':
      'Don\'t send money, phone credit, or any codes to this person.',
  'Orang ini sedang mengumpulkan data pribadimu.':
      'This person is collecting your personal information.',
  'Yang ditawarkan ke kamu bisa membahayakan.':
      'What they\'re offering you could be harmful.',
  'Percakapan ini mulai kasar. Kamu boleh berhenti kapan saja.':
      'This conversation is getting rude. You can stop anytime.',
  'Orang dewasa yang baik tidak akan pernah minta anak menyimpan rahasia dari orang tuanya. Kamu sudah benar dengan tidak langsung menuruti.':
      'A good adult will never ask a child to keep secrets from their parents. You did the right thing by not just going along.',
  'Pelaku biasanya mengancam agar kamu diam. Begitu orang dewasa tahu, ancamannya kehilangan kekuatan.':
      'Predators usually threaten you to keep you quiet. Once an adult knows, the threat loses its power.',
  'Pelaku sering mulai dengan pujian soal tubuh untuk melihat apakah kamu akan diam. Bercerita ke orang dewasa menghentikannya.':
      'Predators often start with compliments about your body to see if you stay quiet. Telling an adult stops it.',
  'Situs judi sering menyamar jadi game atau hadiah. Kalau sudah terlanjur main, ceritakan sekarang sebelum utangnya bertambah.':
      'Gambling sites often disguise themselves as games or prizes. If you\'ve already played, tell someone now before the debt grows.',
  'Membalas biasanya membuat mereka makin menjadi. Menyimpan bukti jauh lebih berguna.':
      'Replying usually makes them worse. Saving the evidence is much more useful.',
  'Jangan menemui orang itu sendirian, dan tetap berada di tempat ramai.':
      'Don\'t meet that person alone, and stay in busy places.',
  'Rasa ini bisa berubah, dan ada orang yang siap menemanimu melewatinya.':
      'This feeling can change, and there are people ready to help you through it.',
  'Kalau memang orangnya baik, dia tidak akan keberatan orang tuamu tahu.':
      'If they\'re really a good person, they won\'t mind your parents knowing.',
  'Kode OTP itu seperti kunci rumah. Siapa pun yang memintanya sedang mencoba masuk.':
      'An OTP code is like a house key. Anyone asking for it is trying to get in.',
  'Alamat, nama sekolah, dan foto kartu identitas sebaiknya tidak pernah dikirim ke orang yang kamu kenal dari internet.':
      'Your address, school name, and ID card photos should never be sent to someone you met on the internet.',
  'Tidak ada yang namanya "coba sekali saja" untuk hal seperti ini.':
      'There is no such thing as "just try it once" for something like this.',
  'Kamu boleh keluar dari obrolan yang membuatmu tidak nyaman.':
      'You can leave any conversation that makes you uncomfortable.',
  'Cari orang dewasa yang kamu percaya sekarang.':
      'Find an adult you trust right now.',
  'Kamu bisa menelepon 119 ekstensi 8 untuk bicara dengan konselor.':
      'You can call 119 extension 8 to talk with a counselor.',
  'Tetap bersama orang lain, jangan sendirian dulu.':
      'Stay with other people, don\'t be alone for now.',
  'Berhenti membalas pesannya.': 'Stop replying to their messages.',
  'Jangan hapus chat-nya, itu bukti penting.':
      'Don\'t delete the chat, it\'s important evidence.',
  'Beri tahu orang tua atau guru hari ini juga.':
      'Tell your parents or a teacher today.',
  'Tidak usah membalas pesannya.':
      'You don\'t need to reply to their messages.',
  'Jangan hapus chat-nya, itu bukti.':
      'Don\'t delete the chat, it\'s evidence.',
  'Blokir dan ceritakan ke orang tua atau guru.':
      'Block them and tell your parents or a teacher.',
  'Jangan balas dulu pesannya.': 'Don\'t reply to their messages yet.',
  'Jangan hapus percakapannya, itu bukti.':
      'Don\'t delete the conversation, it\'s evidence.',
  'Blokir kalau kamu merasa perlu.': 'Block them if you feel you need to.',
  'Ceritakan ke orang dewasa yang kamu percaya.': 'Tell an adult you trust.',
  // panic_orb.dart
  'Mengirim SOS ke orang tua': 'Sending SOS to parents',
  'Kirim SOS sekarang. Terkirim otomatis dalam {countdown} detik.':
      'Send SOS now. Sends automatically in {countdown} seconds.',
  'Tombol darurat. Ketuk untuk mengirim SOS ke orang tua.':
      'Emergency button. Tap to send an SOS to your parents.',
  // report_chat_page.dart
  'Terima kasih. Laporanmu sudah tersimpan dan orang tuamu diberi tahu.':
      'Thank you. Your report has been saved and your parents have been notified.',
  'Laporkan chat yang aneh': 'Report a weird chat',
  'Salin pesannya, tempel di sini. Aku akan periksa dan simpan buktinya dengan aman.':
      'Copy the message and paste it here. I\'ll check it and keep the evidence safe.',
  'Dari aplikasi mana?': 'Which app was it from?',
  'Siapa yang mengirim? (boleh dikosongkan)': 'Who sent it? (optional)',
  'Nama akun atau grup': 'Account or group name',
  'Tempel isi pesannya di sini': 'Paste the message here',
  'Contoh:\nDia: jangan bilang siapa-siapa ya...':
      'Example:\nThem: don\'t tell anyone, okay...',
  'Isi laporan ini disimpan sebagai bukti bersegel waktu dan hanya bisa dibuka orang tuamu.':
      'This report is saved as time-sealed evidence and can only be opened by your parents.',
  'Mengirim...': 'Sending...',
  'Kirim ke AURA': 'Send to AURA',
  'Laporkan': 'Report',
  // aura_robot.dart
  'Aura, robot penjaga': 'Aura, the guardian robot',
  // chat_scan_status.dart
  'Pemindaian chat aktif': 'Chat scanning is on',
  'Pemindaian chat belum aktif': 'Chat scanning is not on yet',
  'Pesan masuk dari WhatsApp, Instagram, TikTok, Telegram, SMS, chat game Roblox, dan aplikasi chat lain diperiksa di ponsel ini. Hanya yang berbahaya sampai ke orang tuamu.':
      'Incoming messages from WhatsApp, Instagram, TikTok, Telegram, SMS, Roblox game chat, and other chat apps are checked on this phone. Only dangerous ones reach your parents.',
  'Pesan yang masuk belum diperiksa. Nyalakan "Akses notifikasi" untuk AURA supaya pesan berbahaya bisa terdeteksi.':
      'Incoming messages are not being checked yet. Turn on "Notification access" for AURA so dangerous messages can be detected.',
  'Nyalakan di Pengaturan': 'Turn on in Settings',
  // location_guard.dart
  'GPS masih mati. Kalau kamu menekan tombol darurat, lokasimu tidak bisa dikirim ke orang tuamu.':
      'GPS is still off. If you press the emergency button, your location can\'t be sent to your parents.',
  // loading_page.dart
  'Masih menyambungkan...': 'Still connecting...',
  'Memuat AURA...': 'Loading AURA...',
  'Periksa koneksi internet. AURA akan tersambung sendiri begitu jaringan kembali.':
      'Check your internet connection. AURA will reconnect on its own once the network is back.',
  // welcome_page.dart
  'Meet The': 'Meet The',
  'AURA': 'AURA',
  'Perlindungan anak bertenaga AI dan pendamping langkah hukum.':
      'AI-powered child protection and a guide for legal action.',
  'Aman di dunia maya, tenang di dunia nyata.':
      'Safe online, at peace offline.',
  'AI yang selalu waspada, 24/7 untuk mereka.':
      'AI that is always alert, 24/7 for them.',
  'Satu aplikasi, sejuta perlindungan.': 'One app, a million protections.',
  'Handphone Orang Tua': 'Parent\'s Phone',
  'Handphone Anak': 'Child\'s Phone',
  'Dengan melanjutkan, Anda menyetujui bahwa AURA dipasang secara terbuka dan diketahui anak.':
      'By continuing, you agree that AURA is installed openly and your child knows about it.',
  // alert_card.dart
  'Belum ditinjau': 'Not reviewed',
  // alert_detail_page.dart
  'Apakah Anda sudah benar menangani ancaman ini?':
      'Have you properly handled this threat?',
  'Kalau sudah, peringatan ini ditandai selesai dan tidak lagi muncul sebagai ancaman yang menunggu tindakan. Bukti tetap tersimpan utuh.':
      'If so, this alert is marked as done and no longer shows as a threat awaiting action. The evidence stays fully stored.',
  'Ancaman ini ditandai sudah ditangani.': 'This threat is marked as handled.',
  'Peringatan': 'Alert',
  'Peringatan tidak ditemukan': 'Alert not found',
  'Peringatan ini mungkin sudah dihapus.': 'This alert may have been deleted.',
  'Rincian Peringatan': 'Alert Details',
  'Tandai peringatan': 'Mark alert',
  'Tandai sudah dilihat': 'Mark as seen',
  'Tandai aman': 'Mark as safe',
  'Tandai dieskalasi': 'Mark as escalated',
  'Kutipan pemicu': 'Triggering excerpt',
  'Hanya bagian yang memicu deteksi yang disimpan.':
      'Only the part that triggered the detection is stored.',
  'Rincian deteksi': 'Detection details',
  'Waktu': 'Time',
  'Anak': 'Child',
  'Aplikasi': 'App',
  'Lawan bicara': 'Chat partner',
  'Sumber': 'Source',
  'Skor risiko': 'Risk score',
  '{toStringAsFixed} dari 100': '{toStringAsFixed} out of 100',
  'Kategori': 'Category',
  'Pola terdeteksi': 'Patterns detected',
  'Lokasi': 'Location',
  'Bukti tersegel': 'Sealed evidence',
  '{count} entri terkait peringatan ini.':
      '{count} entries linked to this alert.',
  'Tidak ada bukti yang tertaut ke peringatan ini.':
      'No evidence is linked to this alert.',
  'Buka langkah hukum': 'Open legal steps',
  'Sudah ditangani': 'Handled',
  'Saya sudah menangani ini': 'I\'ve handled this',
  'SHA-256': 'SHA-256',
  // forensics_timeline_page.dart
  'Log masih kosong': 'The log is still empty',
  'Setiap peringatan yang muncul akan otomatis menyimpan buktinya di sini, lengkap dengan stempel waktu dan sidik digital.':
      'Every alert automatically saves its evidence here, complete with a timestamp and digital fingerprint.',
  'Forensik Timeline': 'Forensic Timeline',
  'Rantai bukti utuh - {total} bukti tersegel':
      'Evidence chain intact - {total} sealed items',
  'Rantai bukti terputus. {reason}': 'Evidence chain broken. {reason}',
  'Belum ada bukti dengan level ini.': 'No evidence at this level yet.',
  'Bukti #{sequence}': 'Evidence #{sequence}',
  'Isi bukti': 'Evidence content',
  'Metadata integritas': 'Integrity metadata',
  'Nomor urut': 'Sequence number',
  'Waktu kejadian': 'Time of incident',
  'Waktu tersimpan': 'Time stored',
  'Diambil oleh': 'Collected by',
  'Hash isi': 'Content hash',
  'Hash rantai': 'Chain hash',
  'Hash sebelumnya': 'Previous hash',
  'Dasar perolehan': 'Basis for collection',
  '{label} disalin': '{label} copied',
  // legal_action_page.dart
  'Gagal membuat berkas: {error}': 'Couldn\'t create the file: {error}',
  'Tidak bisa membuka {value}': 'Couldn\'t open {value}',
  'Langkah yang harus Anda lakukan': 'Steps you should take',
  'Urut dari yang paling mendesak.': 'Ordered from most urgent.',
  'Hubungi sekarang': 'Contact now',
  'Kanal resmi yang menangani kasus anak.':
      'Official channels that handle child cases.',
  'Dasar hukum yang relevan': 'Relevant legal basis',
  'Belum ada pemetaan untuk kategori ini.': 'No mapping for this category yet.',
  '{count} pasal dipetakan dari jenis ancaman.':
      '{count} articles mapped from the threat type.',
  'Berkas Bukti Siap Lapor': 'Report-Ready Evidence File',
  'AURA menyusun kronologi, daftar bukti bersegel waktu, hasil verifikasi integritas, dan rujukan pasal menjadi satu PDF yang bisa Anda serahkan ke penyidik.':
      'AURA compiles the timeline, the list of time-sealed evidence, integrity check results, and legal article references into one PDF you can hand to investigators.',
  'Kejadian': 'Incidents',
  'Bukti': 'Evidence',
  'Integritas': 'Integrity',
  'Putus': 'Broken',
  'Menyusun berkas...': 'Preparing file...',
  'Buat & bagikan berkas PDF': 'Create & share PDF file',
  // legal_hub_tab.dart
  'Pusat Aksi Hukum': 'Legal Action Center',
  'Buat laporan Polisi': 'File a police report',
  'Langsung ke Sistem SPKT': 'Straight to the SPKT system',
  'Laporan polisi kini bisa dibuat online lewat Super App Polri dan diverifikasi petugas SPKT. Siapkan berkas bukti PDF dari AURA (di bawah halaman ini) sebelum melapor.':
      'Police reports can now be filed online through the Super App Polri and verified by SPKT officers. Prepare the evidence PDF from AURA (at the bottom of this page) before reporting.',
  'Lapor online lewat Super App Polri': 'Report online via Super App Polri',
  'Aplikasi resmi Polri. Tidak perlu datang ke kantor polisi.':
      'The official Indonesian Police app. No need to go to a police station.',
  'Super App Polri': 'Super App Polri',
  'Datang ke SPKT terdekat': 'Go to the nearest SPKT',
  'Sentra Pelayanan Kepolisian Terpadu di Polres atau Polsek.':
      'Integrated Police Service Center at the district or sub-district police station.',
  'SPKT Polres terdekat': 'SPKT Polres terdekat',
  'Kejahatan siber: Patroli Siber': 'Cybercrime: Patroli Siber',
  'Pelaporan tindak pidana siber ke Bareskrim Polri.':
      'Report cybercrimes to the National Police Criminal Investigation Agency (Bareskrim).',
  'Darurat: telepon 110': 'Emergency: call 110',
  'Bila anak sedang dalam bahaya saat ini juga.':
      'If your child is in danger right now.',
  'Hubungi Unit PPA': 'Contact the PPA Unit',
  'Polisi / Pendampingan Anak': 'Police / Child Assistance',
  'Unit PPA (Pelayanan Perempuan dan Anak) di Polres menyidik kasus anak. SAPA 129 dari KemenPPPA menerima laporan 24 jam, gratis, dan rahasia, lalu menghubungkan ke pendampingan.':
      'The PPA Unit (Women and Children Services) at district police stations investigates child cases. SAPA 129 from the Ministry of Women Empowerment and Child Protection takes reports 24 hours a day, free and confidential, and connects you to support.',
  'SAPA 129: telepon': 'SAPA 129: call',
  'Layanan KemenPPPA untuk kekerasan terhadap anak.':
      'The ministry\'s service for violence against children.',
  'SAPA 129: WhatsApp': 'SAPA 129: WhatsApp',
  'SAPA 129: formulir online': 'SAPA 129: online form',
  'Unit PPA Polres terdekat': 'Unit PPA Polres terdekat',
  'Penyidik khusus kasus perempuan dan anak.':
      'Specialist investigators for cases involving women and children.',
  'Unit PPA Polres': 'Unit PPA Polres',
  'UPTD PPA terdekat': 'Nearest UPTD PPA',
  'Pendampingan psikologis dan hukum dari pemerintah daerah.':
      'Psychological and legal support from the local government.',
  'UPTD PPA': 'UPTD PPA',
  'Komnas Anak & KPAI': 'Komnas Anak & KPAI',
  'Layanan Pengaduan dan Konsultasi': 'Complaints and Consultation Services',
  'KPAI adalah lembaga negara pengawas perlindungan anak. Komnas Perlindungan Anak adalah lembaga masyarakat yang menerima pengaduan dan konsultasi.':
      'KPAI is the state body that oversees child protection. Komnas Perlindungan Anak is a civil society organization that accepts complaints and consultations.',
  'KPAI: WhatsApp pengaduan': 'KPAI: WhatsApp complaints',
  '0811-1002-7727. Sejak Mei 2024 pengaduan KPAI lewat WhatsApp.':
      '0811-1002-7727. Since May 2024, KPAI complaints go through WhatsApp.',
  'KPAI: formulir pengaduan': 'KPAI: complaint form',
  'Komnas Perlindungan Anak: WhatsApp': 'Komnas Perlindungan Anak: WhatsApp',
  '0822-2888-8454 (dari akun resmi @komnasanak).':
      '0822-2888-8454 (from the official @komnasanak account).',
  'LBH & Bantuan Hukum': 'LBH & Legal Aid',
  'Konsultasi Hukum Gratis': 'Free Legal Consultation',
  'Negara membiayai bantuan hukum gratis lewat LBH terakreditasi BPHN (Kementerian Hukum), terutama bagi warga tidak mampu dengan surat keterangan tidak mampu.':
      'The state funds free legal aid through BPHN-accredited LBH offices (Ministry of Law), especially for low-income residents with a certificate of financial hardship.',
  'Cari LBH gratis terdekat': 'Find the nearest free LBH',
  'SIDBankum: daftar resmi organisasi bantuan hukum.':
      'SIDBankum: the official list of legal aid organizations.',
  'Konsultasi hukum online': 'Online legal consultation',
  'Legal Smart Channel BPHN, gratis.': 'Legal Smart Channel by BPHN, free.',
  'LPSK: telepon 148': 'LPSK: call 148',
  'Perlindungan bagi saksi dan korban, termasuk anak.':
      'Protection for witnesses and victims, including children.',
  'Tidak bisa membuka {label}.': 'Couldn\'t open {label}.',
  'Satu Ketukan, Perlindungan Hukum!': 'One Tap, Legal Protection!',
  'Telepon 112, Layanan Darurat Nasional':
      'Call 112, National Emergency Service',
  'telepon 112': 'call 112',
  'Kontak Darurat': 'Emergency Contacts',
  'Layanan Darurat Nasional': 'National Emergency Service',
  // pairing_page.dart
  'Keluarga {name}': '{name} Family',
  'Tautkan Perangkat Anak': 'Link Child\'s Device',
  'Kode penautan': 'Pairing code',
  'Kode disalin': 'Code copied',
  'Ketuk kode untuk menyalin. Berlaku 24 jam.':
      'Tap the code to copy it. Valid for 24 hours.',
  'Cara menautkan': 'How to link',
  'Pasang AURA di ponsel anak lewat Play Store, lalu buka aplikasinya.':
      'Install AURA on your child\'s phone from the Play Store, then open the app.',
  'Di ponsel anak, pilih "Handphone Anak" dan isi namanya.':
      'On your child\'s phone, choose "Child\'s Phone" and enter their name.',
  'Masukkan kode di atas saat diminta.': 'Enter the code above when asked.',
  'Dampingi anak membaca layar persetujuan. Jelaskan bahwa ini untuk melindunginya, bukan untuk memata-matai.':
      'Read the consent screen together with your child. Explain that this is to protect them, not to spy on them.',
  'Anak yang tahu dan setuju jauh lebih mungkin bercerita saat ada masalah. Perlindungan yang disembunyikan justru merusak kepercayaan yang Anda butuhkan.':
      'Children who know and agree are much more likely to speak up when something is wrong. Hidden protection actually damages the trust you need.',
  // parent_dashboard_page.dart
  'Bunda': 'Mom',
  'Perlindungan aktif': 'Protection on',
  'Perlindungan dijeda': 'Protection paused',
  'Belum': 'Not yet',
  'Sudah': 'Yes',
  'Peringatan terbaru': 'Latest alerts',
  'Tidak ada yang menunggu tindakan': 'Nothing awaiting action',
  '{count} menunggu tindakan': '{count} awaiting action',
  'Tidak ada yang mencurigakan sejauh ini. Kami tetap berjaga.':
      'Nothing suspicious so far. We\'re still keeping watch.',
  'Semua peringatan sudah Anda tangani. Kami tetap berjaga.':
      'You\'ve handled every alert. We\'re still keeping watch.',
  'Halo {name},': 'Hello {name},',
  'Anakmu aman, kita pantau bersama!':
      'Your child is safe, we\'re watching together!',
  'Ada {waiting} hal yang perlu Anda lihat.':
      'There are {waiting} things you should look at.',
  'AICyber Threat Heatmap': 'AICyber Threat Heatmap',
  'Status Proteksi': 'Protection Status',
  'BELUM ADA ANAK': 'NO CHILD YET',
  'Ketuk di sini untuk menautkan HP anak dan mulai melindungi.':
      'Tap here to link your child\'s phone and start protecting them.',
  'PEMINDAIAN CHAT MATI': 'CHAT SCANNING OFF',
  'Akses notifikasi di HP {cName} dimatikan, jadi chat-nya tidak dipindai. Minta {cName} menyalakannya lagi di AURA, menu Pengaturan.':
      'Notification access on {cName}\'s phone is turned off, so their chats aren\'t scanned. Ask {cName} to turn it back on in AURA, in the Settings menu.',
  'Anda sedang menjeda perlindungan untuk {paused}. Ketuk namanya di bawah untuk menyalakannya lagi.':
      'You have paused protection for {paused}. Tap their name below to turn it back on.',
  '{waiting} belum menyetujui perlindungan di HP-nya. Pemindaian dimulai setelah anak setuju.':
      '{waiting} hasn\'t agreed to protection on their phone yet. Scanning starts once your child agrees.',
  'Virtual AI Shield berjalan': 'Virtual AI Shield running',
  'Status pemindaian chat di HP {unknown} belum diketahui. Perbarui aplikasi AURA di HP tersebut.':
      'Chat scanning status on {unknown}\'s phone is unknown. Update the AURA app on that phone.',
  '{first} dan {last}': '{first} and {last}',
  'Anak terhubung': 'Connected children',
  'Tautkan': 'Link',
  'Belum ada HP anak yang ditautkan. Ketuk "Tautkan" untuk membuat kode penautan.':
      'No child phone linked yet. Tap "Link" to create a pairing code.',
  'Sedang Online': 'Online now',
  'Belum pernah aktif': 'Never active',
  'Aktif {lastSeen}': 'Active {lastSeen}',
  'Menunggu persetujuan': 'Waiting for consent',
  'Chat tidak dipindai': 'Chats not scanned',
  '{age} Tahun | ': '{age} years old | ',
  '{age} Tahun': '{age} years old',
  'Perangkat': 'Device',
  'Pemindaian chat': 'Chat scanning',
  'Mati': 'Off',
  'Belum diketahui': 'Unknown',
  'Matikan untuk menjeda pemindaian di HP {childName} sementara.':
      'Turn off to pause scanning on {childName}\'s phone for a while.',
  'Chat {childName} sedang tidak dipindai. Nyalakan lagi kapan saja.':
      '{childName}\'s chats aren\'t being scanned. Turn it back on anytime.',
  'baru saja': 'just now',
  '{count} menit lalu': '{count} min ago',
  '{count} jam lalu': '{count} h ago',
  '{count} hari lalu': '{count} days ago',
  // parent_shell.dart
  'LOG BUKTI': 'EVIDENCE LOG',
  'LAPORAN': 'REPORTS',
  'PROFIL': 'PROFILE',
  'Kembali ke Beranda': 'Back to Home',
  '{label}, {badge} menunggu tindakan': '{label}, {badge} awaiting action',
  // app_state.dart
  'Belum masuk.': 'Not signed in.',
  'Login anonim belum dinyalakan. Di Supabase, buka Authentication > Providers > Anonymous, lalu nyalakan.':
      'Anonymous sign-in is not enabled. In Supabase, open Authentication > Providers > Anonymous, then turn it on.',
  'Tabel database belum dibuat. Jalankan isi supabase/schema.sql di SQL Editor Supabase.':
      'Database tables haven\'t been created. Run the contents of supabase/schema.sql in the Supabase SQL Editor.',
  'Kunci Supabase tidak cocok. Periksa lagi isi lib/supabase_options.dart.':
      'The Supabase key doesn\'t match. Check lib/supabase_options.dart again.',
  'Akses ditolak oleh aturan keamanan. Pastikan seluruh isi schema.sql sudah dijalankan.':
      'Access denied by security rules. Make sure all of schema.sql has been run.',
  'Tidak bisa terhubung ke internet. Periksa koneksi Anda, lalu coba lagi.':
      'Can\'t connect to the internet. Check your connection, then try again.',
  'Terjadi masalah saat menghubungi server. Coba lagi sebentar lagi.\n\n({text})':
      'There was a problem contacting the server. Try again in a moment.\n\n({text})',
  // data
  'Ada': 'Yes, there is',
  'Ada orang yang ganggu aku': 'Someone is bothering me',
  'Ada satu': 'There\'s one',
  'Ada yang chat aku terus': 'Someone keeps messaging me',
  'Ada yang ganggu aku': 'Someone is bothering me',
  'Ada yang minta fotoku': 'Someone asked for my photo',
  'Ada yang minta password': 'Someone asked for my password',
  'Ada yang nawarin': 'Someone offered me',
  'Ada yang ngajak chat di luar game': 'Someone wants to chat outside the game',
  'Ada yang ngatain aku': 'Someone called me names',
  'Ajakan Bertemu Diam-diam': 'Secret Meetup Invitation',
  'Aku belum siap': 'I\'m not ready yet',
  'Aku capek aja': 'I\'m just tired',
  'Aku dibully di sekolah': 'I\'m being bullied at school',
  'Aku dijauhi teman': 'My friends are leaving me out',
  'Aku dimarahi': 'I got scolded',
  'Aku dimarahi guru': 'My teacher scolded me',
  'Aku lagi sedih': 'I\'m feeling sad',
  'Aku malu cerita': 'I\'m embarrassed to tell',
  'Aku masih malu': 'I\'m still embarrassed',
  'Aku masih takut': 'I\'m still scared',
  'Aku mau blokir dia': 'I want to block them',
  'Aku mau cerita': 'I want to tell you something',
  'Aku mau cerita dulu': 'I want to talk first',
  'Aku mau cerita ke guru': 'I want to tell my teacher',
  'Aku mau cerita lagi': 'I want to talk more',
  'Aku mau ngobrol sama kamu aja': 'I just want to talk to you',
  'Aku menang': 'I won',
  'Aku sedang sendirian': 'I\'m alone right now',
  'Aku sering sendirian': 'I\'m often alone',
  'Aku sudah coba': 'I\'ve tried',
  'Aku sudah janji ketemu': 'I already promised to meet',
  'Aku sudah terlanjur kasih': 'I already gave it',
  'Aku sudah terlanjur kirim': 'I already sent it',
  'Aku sudah terlanjur main': 'I\'ve already played',
  'Aku takut': 'I\'m scared',
  'Aku takut dimarahi': 'I\'m afraid of getting scolded',
  'Aku tolak': 'I said no',
  'Aku udah bilang': 'I already told them',
  'Aku udah janji ketemu': 'I already promised to meet',
  'Aku udah klik link': 'I already clicked the link',
  'Aku udah terlanjur kasih': 'I already gave it',
  'Aku udah terlanjur kirim': 'I already sent it',
  'Akunku dibajak': 'My account got hacked',
  'Aman': 'Safe',
  'Amankan benda berbahaya': 'Secure dangerous items',
  'Amankan bukti, jangan hapus apa pun':
      'Secure the evidence, don\'t delete anything',
  'Ancaman Kekerasan': 'Threat of Violence',
  'Ancaman Kekerasan melalui Sarana Elektronik':
      'Threats of Violence via Electronic Means',
  'Ancaman pidana pokok ditambah 1/3.':
      'The basic criminal penalty plus one third.',
  'Baik': 'Good',
  'Baru': 'New',
  'Baru sekali': 'Just once',
  'Bawa KTP orang tua, Kartu Keluarga, akta kelahiran anak, dan berkas bukti AURA (cetak serta salinan digital). Mintalah Surat Tanda Penerimaan Laporan (STPL) sebagai tanda laporan diterima.':
      'Bring the parent\'s ID card (KTP), Family Card, the child\'s birth certificate, and the AURA evidence file (printed and digital). Ask for a Report Receipt Letter (STPL) as proof the report was accepted.',
  'Beranda': 'Home',
  'Beri tahu orang tuaku': 'Tell my parents',
  'Berita Bohong yang Merugikan Konsumen': 'False News Harming Consumers',
  'Bervariasi menurut golongan; melibatkan anak diperberat (Pasal 133).':
      'Varies by drug class; heavier when children are involved (Article 133).',
  'Biasa aja': 'Just okay',
  'Bila tekanan datang dari perundungan atau ajakan pihak lain, barulah siapkan berkas bukti untuk dilaporkan.':
      'If the pressure comes from bullying or someone else egging them on, then prepare the evidence file for a report.',
  'Boleh, kasih tahu mereka': 'Okay, tell them',
  'Buka Vault Forensik AURA dan unduh berkas bukti (PDF + lampiran). Berkas sudah memuat stempel waktu dan nilai hash tiap bukti.':
      'Open the AURA Forensic Vault and download the evidence file (PDF + attachments). The file already includes timestamps and hash values for each piece of evidence.',
  'Capek banget': 'I\'m really tired',
  'Capek pikiran': 'My mind is tired',
  'Catatan Sistem': 'System Note',
  'Ceritanya rahasia kan?': 'This is secret, right?',
  'Chat Game': 'Game Chat',
  'Cuma kesel aja': 'I\'m just annoyed',
  'Dampingi anak sekarang juga. Dengarkan tanpa menghakimi dan jangan tinggalkan sendirian. Keselamatan jiwa mendahului urusan bukti dan pelaporan.':
      'Stay with your child right now. Listen without judging and do not leave them alone. Their safety comes before evidence and reporting.',
  'Dapat nilai bagus': 'I got a good grade',
  'Datangi SPKT Polres terdekat': 'Go to the nearest police SPKT',
  'Dengerin musik': 'Listen to music',
  'Dia ancam sebar fotoku': 'They threatened to spread my photo',
  'Dia bikin akun baru': 'They made a new account',
  'Dia bilang ini rahasia kita': 'They said this is our secret',
  'Dia janji hadiah': 'They promised a prize',
  'Dia maksa': 'They keep pushing',
  'Dia maksa terus': 'They won\'t stop pushing',
  'Dia mengancam aku': 'They\'re threatening me',
  'Dia minta fotoku': 'They asked for my photo',
  'Dia nanya alamatku': 'They asked for my address',
  'Dia ngajak ketemu': 'They asked to meet up',
  'Dia ngatain aku': 'They called me names',
  'Dia ngatain terus': 'They keep calling me names',
  'Dia ngejek aku': 'They\'re making fun of me',
  'Dia orang dewasa': 'They\'re an adult',
  'Dia tahu rumahku': 'They know where I live',
  'Dieskalasi ke Pihak Berwajib': 'Escalated to Authorities',
  'Dilaporkan Anak': 'Reported by Child',
  'Distribusi Konten Melanggar Kesusilaan': 'Distribution of Indecent Content',
  'Distribusi Muatan Perjudian': 'Distribution of Gambling Content',
  'Ditandai Aman': 'Marked Safe',
  'Gak ada': 'Nothing',
  'Gak tahu kenapa': 'I don\'t know why',
  'Gimana caranya blokir?': 'How do I block someone?',
  'Grooming / Pendekatan Predator': 'Grooming / Predatory Approach',
  'Hahaha': 'Hahaha',
  'Hard': 'Hard',
  'Hindari memarahi, menyita ponsel sebagai hukuman, atau menuduh anak mencari perhatian.':
      'Avoid scolding, confiscating the phone as punishment, or accusing your child of seeking attention.',
  'Hubungi 110 bila bahaya sedang berlangsung':
      'Call 110 if the danger is happening now',
  'Hubungi layanan kesehatan jiwa': 'Contact a mental health service',
  'Ide lain dong': 'Give me another idea',
  'Indikasi Menyakiti Diri': 'Signs of Self-Harm',
  'Informasi hukum di bawah ini bersifat umum dan disusun untuk membantu Anda menyiapkan laporan. Penetapan pasal sepenuhnya merupakan kewenangan penyidik. Untuk pendampingan, hubungi UPTD PPA di daerah Anda atau layanan SAPA 129.':
      'The legal information below is general and meant to help you prepare a report. Deciding which articles apply is entirely up to investigators. For support, contact the UPTD PPA in your area or the SAPA 129 service.',
  'Instagram DM': 'Instagram DM',
  'Iya, aku cerita': 'Yes, I\'ll tell them',
  'Iya, bantu aku': 'Yes, help me',
  'Iya, gimana caranya': 'Yes, how do I do it?',
  'Jangan konfrontasi pelaku': 'Don\'t confront the perpetrator',
  'Jangan membalas, memancing, atau menghapus percakapan. Pesan yang dihapus menyulitkan pembuktian.':
      'Don\'t reply, provoke, or delete the conversation. Deleted messages make proving the case harder.',
  'Jauhkan obat-obatan, benda tajam, dan akses ke tempat berisiko selama masa krisis.':
      'Keep medicines, sharp objects, and access to risky places away during the crisis.',
  'Jika anak sedang diancam, dibuntuti, atau diajak bertemu hari ini, perlakukan sebagai keadaan darurat.':
      'If your child is being threatened, followed, or asked to meet today, treat it as an emergency.',
  'Judi Online': 'Online Gambling',
  'Kalah main game': 'I lost a game',
  'Kalah terus': 'I keep losing',
  'Kamu bisa apa aja?': 'What can you do?',
  'Karena main HP': 'Because of my phone',
  'Karena nilai': 'Because of my grades',
  'Kata Kasar Berlebihan': 'Excessive Profanity',
  'Kebocoran Data Pribadi': 'Personal Data Leak',
  'Kekerasan Seksual Berbasis Elektronik': 'Electronic-Based Sexual Violence',
  'Kekerasan dan Ancaman Kekerasan terhadap Anak':
      'Violence and Threats of Violence against Children',
  'Kekerasan terhadap Anak': 'Violence against Children',
  'Kenal di internet': 'I met them online',
  'Konsultasi dan pendampingan kasus melalui pesan.':
      'Case consultation and support via messages.',
  'Kritis': 'Critical',
  'LPSK': 'LPSK',
  'Lagi ada masalah': 'I\'ve got a problem',
  'Lagi dong!': 'Another one!',
  'Lagi marahan': 'We\'re fighting',
  'Lagi nggak enak hati': 'I\'m feeling down',
  'Lagi sedih': 'I\'m sad',
  'Lagi seneng': 'I\'m happy',
  'Lainnya': 'Other',
  'Lapor hanya bila ada pihak yang mendorong anak':
      'Report only if someone else is pushing your child',
  'Laporan': 'Reports',
  'Laporkan akun pelaku ke aplikasi tempat kejadian dan ke aduankonten.id agar kontennya diturunkan.':
      'Report the perpetrator\'s account to the app where it happened and to aduankonten.id so the content is taken down.',
  'Laporkan juga ke platformnya': 'Report it to the platform too',
  'Layanan pengaduan kekerasan terhadap perempuan dan anak, 24 jam.':
      'Complaint service for violence against women and children, 24 hours.',
  'Log': 'Log',
  'Low': 'Low',
  'Main game': 'Play games',
  'Main game bareng': 'Play games together',
  'Main sama teman': 'Play with friends',
  'Makasih Aura': 'Thanks, Aura',
  'Masalah di rumah': 'Problems at home',
  'Matematika': 'Math',
  'Mau': 'Sure',
  'Medium': 'Medium',
  'Melarang memproduksi dan menyebarluaskan pornografi; pidana ditambah sepertiga bila melibatkan anak.':
      'Prohibits producing and spreading pornography; the penalty increases by one third when children are involved.',
  'Melarang mendistribusikan atau membuat dapat diaksesnya informasi elektronik bermuatan melanggar kesusilaan.':
      'Prohibits distributing or making accessible electronic information with indecent content.',
  'Melarang menempatkan, membiarkan, melakukan, menyuruh, atau turut serta dalam penculikan, penjualan, atau perdagangan anak.':
      'Prohibits placing, allowing, committing, ordering, or taking part in the kidnapping, sale, or trafficking of children.',
  'Melarang menempatkan, membiarkan, melibatkan, menyuruh melibatkan anak dalam penyalahgunaan atau produksi narkotika.':
      'Prohibits placing, allowing, involving, or ordering the involvement of children in drug abuse or drug production.',
  'Melarang menyiarkan, mendistribusikan, atau membuat dapat diaksesnya informasi elektronik yang bermuatan perjudian.':
      'Prohibits broadcasting, distributing, or making accessible electronic information with gambling content.',
  'Melarang pengiriman informasi elektronik yang berisi ancaman kekerasan yang ditujukan secara pribadi.':
      'Prohibits sending electronic information containing threats of violence directed at a person.',
  'Melarang setiap orang melakukan kekerasan, ancaman, tipu muslihat, atau membujuk anak untuk melakukan atau membiarkan dilakukan perbuatan cabul.':
      'Prohibits anyone from using violence, threats, deception, or persuasion to make a child commit or allow indecent acts.',
  'Melarang setiap orang memperoleh atau mengumpulkan data pribadi yang bukan miliknya untuk menguntungkan diri sendiri atau orang lain yang dapat merugikan subjek data.':
      'Prohibits anyone from obtaining or collecting personal data that is not theirs to benefit themselves or others in a way that harms the data subject.',
  'Melarang setiap orang menempatkan, membiarkan, melakukan, atau turut serta melakukan kekerasan terhadap anak, termasuk kekerasan psikis.':
      'Prohibits anyone from placing, allowing, committing, or taking part in violence against children, including psychological violence.',
  'Menghubungi pelaku membuat dia sadar dan biasanya langsung menghapus akun serta jejak digitalnya.':
      'Contacting the perpetrator alerts them, and they usually delete their account and digital traces right away.',
  'Menjerat kekerasan fisik maupun ancamannya yang ditujukan kepada anak.':
      'Covers physical violence and threats of violence directed at children.',
  'Menjerat kepemilikan, peredaran, dan penyalahgunaan narkotika; pidana diperberat bila melibatkan anak di bawah umur.':
      'Covers possession, trafficking, and abuse of narcotics; heavier penalties when minors are involved.',
  'Menjerat pelaku yang memakai konten seksual korban untuk memeras, mengancam, atau memaksa korban melakukan sesuatu.':
      'Covers perpetrators who use a victim\'s sexual content to extort, threaten, or force the victim to do something.',
  'Menjerat pemaksaan dengan kekerasan atau ancaman agar korban menyerahkan barang atau memberi utang.':
      'Covers coercion through violence or threats to make a victim hand over goods or take on a debt.',
  'Menjerat pengiriman anak ke dalam atau ke luar negeri dengan cara apa pun yang mengakibatkan anak tereksploitasi.':
      'Covers sending children into or out of the country by any means that results in their exploitation.',
  'Menjerat penyebaran berita bohong yang menimbulkan kerugian materiel dalam transaksi elektronik.':
      'Covers spreading false news that causes material losses in electronic transactions.',
  'Menjerat penyerangan kehormatan atau nama baik orang lain melalui sarana elektronik agar diketahui umum.':
      'Covers attacks on another person\'s honor or reputation through electronic means made public.',
  'Menjerat perbuatan merekam, mengirim, atau memperdaya korban melalui sarana elektronik yang bermuatan seksual.':
      'Covers recording, sending, or deceiving a victim through electronic means with sexual content.',
  'Menjerat perbuatan seksual nonfisik, termasuk ucapan atau pesan yang ditujukan pada tubuh atau keinginan seksual, yang merendahkan harkat dan martabat korban.':
      'Covers non-physical sexual acts, including remarks or messages about the victim\'s body or sexual desires that degrade the victim\'s dignity.',
  'Mereka menyediakan pendampingan hukum dan psikologis gratis bagi anak korban, termasuk saat pemeriksaan di kepolisian.':
      'They provide free legal and psychological support for child victims, including during police questioning.',
  'Mereka ngejek aku': 'They\'re making fun of me',
  'Mimpi buruk': 'Nightmare',
  'Minta pendampingan UPTD PPA atau SAPA 129':
      'Ask for support from UPTD PPA or SAPA 129',
  'Nanti aja': 'Maybe later',
  'Nggak ada': 'Nothing',
  'Ngobrol di sekolah': 'Chat at school',
  'Ngobrol sama teman': 'Talk with friends',
  'Nilaiku jelek': 'My grades are bad',
  'Nyaman kok': 'I\'m comfortable',
  'Oke aku hapus': 'Okay, I\'ll delete it',
  'Oke, aku bilang': 'Okay, I\'ll tell them',
  'Oke, aku cerita': 'Okay, I\'ll talk',
  'Oke, aku coba': 'Okay, I\'ll try',
  'Oke, aku nggak pergi': 'Okay, I won\'t go',
  'Oke, aku stop': 'Okay, I\'ll stop',
  'Panggilan darurat terpadu di seluruh Indonesia.':
      'Integrated emergency calls throughout Indonesia.',
  'Patroli Siber': 'Patroli Siber',
  'Pelajarannya susah': 'The lessons are hard',
  'Pelaporan tindak pidana siber secara daring.':
      'Online reporting of cybercrimes.',
  'Pelecehan Seksual': 'Sexual Harassment',
  'Pelecehan Seksual Nonfisik': 'Non-Physical Sexual Harassment',
  'Pelibatan Anak dalam Penyalahgunaan Narkotika':
      'Involving Children in Drug Abuse',
  'Pemberatan bila Korbannya Anak':
      'Heavier Penalty When the Victim Is a Child',
  'Pemerasan': 'Extortion',
  'Pemerasan Seksual Berbasis Elektronik': 'Electronic-Based Sexual Extortion',
  'Pemindai Media': 'Media Scanner',
  'Pemindai Pesan': 'Message Scanner',
  'Penculikan dan Perdagangan Anak': 'Kidnapping and Trafficking of Children',
  'Pengaduan KPAI': 'KPAI Complaints',
  'Pengaduan dan pemantauan kasus perlindungan anak.':
      'Complaints and monitoring of child protection cases.',
  'Pengumpulan Data Pribadi Secara Melawan Hukum':
      'Unlawful Collection of Personal Data',
  'Penipuan / Pemerasan Uang': 'Fraud / Financial Extortion',
  'Penyalahgunaan Narkotika': 'Drug Abuse',
  'Penyerangan Kehormatan atau Nama Baik': 'Attacks on Honor or Reputation',
  'Perbuatan Cabul terhadap Anak': 'Indecent Acts against Children',
  'Permintaan Konten Seksual': 'Requests for Sexual Content',
  'Permohonan perlindungan bagi saksi dan korban.':
      'Requests for protection of witnesses and victims.',
  'Perundungan Siber': 'Cyberbullying',
  'Pidana penjara 3-15 tahun dan denda Rp120-600 juta.':
      'Prison of 3-15 years and a fine of Rp120-600 million.',
  'Pidana penjara 3-15 tahun dan denda hingga Rp300 juta (Pasal 83).':
      'Prison of 3-15 years and a fine of up to Rp300 million (Article 83).',
  'Pidana penjara 5-15 tahun dan denda hingga Rp5 miliar (Pasal 82).':
      'Prison of 5-15 years and a fine of up to Rp5 billion (Article 82).',
  'Pidana penjara 5-20 tahun dan denda Rp200 juta-Rp20 miliar (Pasal 89).':
      'Prison of 5-20 years and a fine of Rp200 million-Rp20 billion (Article 89).',
  'Pidana penjara 6 bulan-12 tahun, ditambah 1/3 bila korbannya anak.':
      'Prison of 6 months-12 years, plus one third if the victim is a child.',
  'Pidana penjara hingga 10 tahun dan/atau denda hingga Rp10 miliar.':
      'Prison of up to 10 years and/or a fine of up to Rp10 billion.',
  'Pidana penjara hingga 2 tahun dan/atau denda hingga Rp400 juta.':
      'Prison of up to 2 years and/or a fine of up to Rp400 million.',
  'Pidana penjara hingga 3 tahun 6 bulan dan/atau denda Rp72 juta (Pasal 80).':
      'Prison of up to 3 years 6 months and/or a fine of Rp72 million (Article 80).',
  'Pidana penjara hingga 3 tahun 6 bulan dan/atau denda Rp72 juta.':
      'Prison of up to 3 years 6 months and/or a fine of Rp72 million.',
  'Pidana penjara hingga 4 tahun dan/atau denda hingga Rp750 juta.':
      'Prison of up to 4 years and/or a fine of up to Rp750 million.',
  'Pidana penjara hingga 5 tahun dan/atau denda hingga Rp5 miliar.':
      'Prison of up to 5 years and/or a fine of up to Rp5 billion.',
  'Pidana penjara hingga 6 tahun dan/atau denda hingga Rp1 miliar.':
      'Prison of up to 6 years and/or a fine of up to Rp1 billion.',
  'Pidana penjara hingga 6 tahun dan/atau denda hingga Rp300 juta.':
      'Prison of up to 6 years and/or a fine of up to Rp300 million.',
  'Pidana penjara hingga 9 bulan dan/atau denda hingga Rp10 juta.':
      'Prison of up to 9 months and/or a fine of up to Rp10 million.',
  'Pidana penjara hingga 9 tahun.': 'Prison of up to 9 years.',
  'Pidana tindak pidana kekerasan seksual ditambah sepertiga bila dilakukan terhadap anak.':
      'The penalty for sexual violence crimes increases by one third when committed against a child.',
  'Polisi (Panggilan Darurat)': 'Police (Emergency Call)',
  'Pornografi yang Melibatkan Anak': 'Pornography Involving Children',
  'Profil': 'Profile',
  'Rahasia ah': 'It\'s a secret',
  'Rekaman Audio': 'Audio Recording',
  'Rendah': 'Low',
  'SAPA 129': 'SAPA 129',
  'SAPA 129 via WhatsApp': 'SAPA 129 via WhatsApp',
  'Salah paham': 'A misunderstanding',
  'Sedang': 'Medium',
  'Semua': 'All',
  'Seru!': 'Fun!',
  'Simpan STPL. Tanpa STPL, Anda sulit menanyakan perkembangan perkara.':
      'Keep the STPL. Without it, it\'s hard to follow up on the case\'s progress.',
  'Simpan buktinya': 'Save the evidence',
  'Soal game': 'About games',
  'Soal sekolah': 'About school',
  'Soal teman': 'About friends',
  'Sudah Dilihat': 'Seen',
  'Sudah lama': 'It\'s been a while',
  'Sudah lama begini': 'It\'s been like this for a while',
  'Tangkapan Layar': 'Screenshot',
  'Tebak-tebakan!': 'Riddle time!',
  'Telepon SEJIWA di 119 ekstensi 8, atau bawa anak ke IGD/puskesmas terdekat bila ada risiko langsung.':
      'Call SEJIWA at 119 extension 8, or take your child to the nearest ER or community health center if there is immediate risk.',
  'Teman sekolah': 'A school friend',
  'Teman yang nawarin': 'A friend offered it',
  'Teman-temanku nyebelin': 'My friends are annoying',
  'Temani anak lebih dulu': 'Stay with your child first',
  'Temanku yang ngajak': 'A friend invited me',
  'Timku nggak kompak': 'My team doesn\'t work together',
  'Tindak Pidana Perdagangan Orang terhadap Anak':
      'Human Trafficking Crimes against Children',
  'Tinggi': 'High',
  'Titik Lokasi': 'Location Point',
  'Tombol Darurat': 'Emergency Button',
  'Transkrip Pesan': 'Message Transcript',
  'Tugasnya banyak banget': 'I have so much homework',
  'Udah': 'Already',
  'Udah aku blokir': 'I already blocked them',
  'Udah dulu ya': 'That\'s all for now',
  'Udah mendingan': 'I feel better now',
  'Udah sering': 'It happens a lot',
  'Udah sering terjadi': 'It\'s happened many times',
  'Untuk ancaman yang sedang berlangsung atau anak dalam bahaya langsung.':
      'For threats in progress or a child in immediate danger.',
  'Zat Terlarang': 'Illegal Substances',
};
