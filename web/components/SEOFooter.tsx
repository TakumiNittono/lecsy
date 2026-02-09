import Link from "next/link";

export default function SEOFooter() {
  return (
    <footer className="border-t border-gray-200 py-12 bg-white">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="grid md:grid-cols-4 gap-8 mb-8">
          {/* Brand */}
          <div>
            <Link href="/" className="text-2xl font-bold bg-gradient-to-r from-blue-600 to-blue-500 bg-clip-text text-transparent mb-4 block">
              lecsy
            </Link>
            <p className="text-gray-600 text-sm">
              Lecture recording & AI transcription app built for college and international students.
            </p>
          </div>
          {/* Features */}
          <div>
            <h4 className="font-semibold text-gray-900 mb-4">Features</h4>
            <ul className="space-y-2 text-sm text-gray-600">
              <li><Link href="/ai-transcription-for-students" className="hover:text-gray-900 transition-colors">AI Transcription for Students</Link></li>
              <li><Link href="/lecture-recording-app-college" className="hover:text-gray-900 transition-colors">Lecture Recording App</Link></li>
              <li><Link href="/ai-note-taking-for-international-students" className="hover:text-gray-900 transition-colors">AI Note Taking for International Students</Link></li>
            </ul>
          </div>
          {/* Resources */}
          <div>
            <h4 className="font-semibold text-gray-900 mb-4">Resources</h4>
            <ul className="space-y-2 text-sm text-gray-600">
              <li><Link href="/otter-alternative-for-lectures" className="hover:text-gray-900 transition-colors">Otter Alternative for Lectures</Link></li>
              <li><Link href="/how-to-record-lectures-legally" className="hover:text-gray-900 transition-colors">How to Record Lectures Legally</Link></li>
            </ul>
          </div>
          {/* Legal */}
          <div>
            <h4 className="font-semibold text-gray-900 mb-4">Legal</h4>
            <ul className="space-y-2 text-sm text-gray-600">
              <li><Link href="/privacy" className="hover:text-gray-900 transition-colors">Privacy Policy</Link></li>
              <li><Link href="/terms" className="hover:text-gray-900 transition-colors">Terms of Service</Link></li>
            </ul>
          </div>
        </div>
        <div className="border-t border-gray-200 pt-8 text-center text-gray-600 text-sm">
          © 2026 lecsy. All rights reserved.
        </div>
      </div>
    </footer>
  );
}
