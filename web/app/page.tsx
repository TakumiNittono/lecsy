import Link from "next/link";
import ProCardUpgradeButton from "@/components/ProCardUpgradeButton";

export default function Home() {
  return (
    <main className="min-h-screen bg-white">
      {/* Header */}
      <header className="border-b border-gray-200 sticky top-0 bg-white/80 backdrop-blur-sm z-50">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4 flex justify-between items-center">
          <div className="text-2xl font-bold bg-gradient-to-r from-blue-600 to-blue-500 bg-clip-text text-transparent">
            lecsy
          </div>
          <div className="flex gap-4">
            <Link
              href="/login"
              className="px-4 py-2 text-gray-700 hover:text-gray-900 transition-colors font-medium"
            >
              Login
            </Link>
            <Link
              href="/login"
              className="px-6 py-2 bg-gradient-to-r from-blue-600 to-blue-500 text-white rounded-lg hover:from-blue-700 hover:to-blue-600 transition-all shadow-lg hover:shadow-xl transform hover:scale-105"
            >
              Get Started
            </Link>
          </div>
        </div>
      </header>

      {/* Hero */}
      <section className="relative overflow-hidden bg-gradient-to-br from-blue-50 via-white to-blue-50 py-20 lg:py-32">
        <div className="absolute inset-0 bg-grid-pattern opacity-5"></div>
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 relative z-10">
          <div className="text-center animate-fade-in-up">
            <div className="inline-block mb-6">
              <span className="px-4 py-2 bg-blue-100 text-blue-700 rounded-full text-sm font-semibold">
                ✨ 100% Free to Start
              </span>
            </div>
            <h1 className="text-5xl lg:text-7xl font-bold text-gray-900 mb-6 leading-tight">
              Lecture Recording & AI Transcription App for Students
            </h1>
            <p className="text-xl lg:text-2xl text-gray-600 mb-6 max-w-2xl mx-auto">
              Record lectures, transcribe them with AI, and review anytime to truly understand your classes.
            </p>
            <div className="mb-8 max-w-2xl mx-auto">
              <p className="text-lg text-gray-700 font-medium mb-3">Designed for:</p>
              <ul className="flex flex-wrap justify-center gap-4 text-gray-600">
                <li className="flex items-center gap-2">
                  <span>•</span>
                  <span>College students</span>
                </li>
                <li className="flex items-center gap-2">
                  <span>•</span>
                  <span>International students</span>
                </li>
                <li className="flex items-center gap-2">
                  <span>•</span>
                  <span>English lectures</span>
                </li>
              </ul>
            </div>
            <div className="flex flex-col sm:flex-row gap-4 justify-center items-center">
              <Link
                href="/login"
                className="group inline-flex items-center gap-2 px-8 py-4 bg-gradient-to-r from-blue-600 to-blue-500 text-white rounded-xl text-lg font-semibold hover:from-blue-700 hover:to-blue-600 transition-all shadow-xl hover:shadow-2xl transform hover:scale-105"
              >
                Get the app — it&apos;s free
                <svg className="w-5 h-5 group-hover:translate-x-1 transition-transform" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 7l5 5m0 0l-5 5m5-5H6" />
                </svg>
              </Link>
              <Link
                href="#how-it-works"
                className="px-8 py-4 text-gray-700 hover:text-gray-900 font-medium transition-colors"
              >
                Learn more →
              </Link>
            </div>
          </div>
          
          {/* Visual Element */}
          <div className="mt-16 flex justify-center animate-fade-in">
            <div className="relative">
              <div className="absolute inset-0 bg-gradient-to-r from-blue-400 to-blue-300 rounded-2xl blur-2xl opacity-30 animate-pulse-slow"></div>
              <div className="relative bg-white rounded-2xl shadow-2xl p-8 border border-gray-100">
                <div className="flex items-center gap-4 mb-4">
                  <div className="w-12 h-12 bg-gradient-to-r from-blue-500 to-blue-400 rounded-full flex items-center justify-center">
                    <svg className="w-6 h-6 text-white" fill="currentColor" viewBox="0 0 24 24">
                      <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 14.5v-9l6 4.5-6 4.5z"/>
                    </svg>
                  </div>
                  <div>
                    <div className="h-2 bg-gray-200 rounded w-32 mb-2"></div>
                    <div className="h-2 bg-gray-200 rounded w-24"></div>
                  </div>
                </div>
                <div className="space-y-2">
                  <div className="h-2 bg-gray-100 rounded w-full"></div>
                  <div className="h-2 bg-gray-100 rounded w-5/6"></div>
                  <div className="h-2 bg-gray-100 rounded w-4/6"></div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Problem */}
      <section className="bg-gray-50 py-20 relative">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <div className="inline-block mb-4">
            <span className="text-6xl">😓</span>
          </div>
          <h2 className="text-4xl lg:text-5xl font-bold text-gray-900 mb-8">
            90-minute lectures. 5 minutes to review.
          </h2>
          <div className="space-y-4 text-lg text-gray-600 max-w-2xl mx-auto">
            <p className="flex items-center justify-center gap-2">
              <span className="text-2xl">📝</span>
              You sit through hours of lectures.
            </p>
            <p className="flex items-center justify-center gap-2">
              <span className="text-2xl">✏️</span>
              You take notes, but miss the important parts.
            </p>
            <p className="flex items-center justify-center gap-2">
              <span className="text-2xl">🤯</span>
              You forget what was said by the time exams come.
            </p>
          </div>
          <p className="text-2xl font-bold text-gray-900 mt-8 gradient-text">
            There&apos;s a better way.
          </p>
        </div>
      </section>

      {/* What is lecsy */}
      <section className="py-20 bg-white">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-12">
            <h2 className="text-4xl lg:text-5xl font-bold text-gray-900 mb-6">
              Lecsy: Lecture Recording & AI Transcription App
            </h2>
          </div>
          <div className="grid md:grid-cols-2 gap-8 items-center">
            <div className="space-y-6">
              <div className="flex items-start gap-4 p-6 bg-gradient-to-br from-blue-50 to-sky-50 rounded-xl hover-lift">
                <div className="w-12 h-12 bg-blue-600 rounded-lg flex items-center justify-center flex-shrink-0">
                  <svg className="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z" />
                  </svg>
                </div>
                <div>
                  <h3 className="font-bold text-gray-900 mb-2">Completely Offline</h3>
                  <p className="text-gray-600">Lecsy lecture recording app records your lectures on iPhone — no internet required.</p>
                </div>
              </div>
              <div className="flex items-start gap-4 p-6 bg-gradient-to-br from-sky-50 to-cyan-50 rounded-xl hover-lift">
                <div className="w-12 h-12 bg-sky-600 rounded-lg flex items-center justify-center flex-shrink-0">
                  <svg className="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                  </svg>
                </div>
                <div>
                  <h3 className="font-bold text-gray-900 mb-2">Local Transcription</h3>
                  <p className="text-gray-600">AI transcription transcribes everything locally, no internet required.</p>
                </div>
              </div>
              <div className="flex items-start gap-4 p-6 bg-gradient-to-br from-cyan-50 to-blue-50 rounded-xl hover-lift">
                <div className="w-12 h-12 bg-cyan-600 rounded-lg flex items-center justify-center flex-shrink-0">
                  <svg className="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                  </svg>
                </div>
                <div>
                  <h3 className="font-bold text-gray-900 mb-2">Read Anywhere</h3>
                  <p className="text-gray-600">When you&apos;re ready, read the full text on the web.</p>
                </div>
              </div>
            </div>
            <div className="text-center">
              <div className="inline-block p-8 bg-gradient-to-br from-blue-100 to-sky-100 rounded-2xl">
                <div className="text-6xl mb-4">✨</div>
                <p className="text-xl font-bold text-gray-900">
                  And when exams come, let AI summarize it in seconds.
                </p>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* How it works */}
      <section id="how-it-works" className="bg-gradient-to-b from-gray-50 to-white py-20">
        <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-16">
            <h2 className="text-4xl lg:text-5xl font-bold text-gray-900 mb-4">
              How it works
            </h2>
            <p className="text-xl text-gray-600">Three simple steps to better learning</p>
          </div>
          <div className="grid md:grid-cols-3 gap-8">
            <div className="text-center p-8 bg-white rounded-2xl shadow-lg hover-lift border border-gray-100">
              <div className="w-20 h-20 bg-gradient-to-r from-blue-500 to-sky-500 rounded-full flex items-center justify-center mx-auto mb-6 text-3xl font-bold text-white shadow-lg">
                1
              </div>
              <div className="text-5xl mb-4">🎙️</div>
              <h3 className="text-2xl font-bold text-gray-900 mb-4">Record</h3>
              <p className="text-gray-600 leading-relaxed">
                Open the app. Tap record. That&apos;s it.
                <br />
                Works in the background, even with your phone locked.
              </p>
            </div>
            <div className="text-center p-8 bg-white rounded-2xl shadow-lg hover-lift border border-gray-100">
              <div className="w-20 h-20 bg-gradient-to-r from-sky-500 to-cyan-500 rounded-full flex items-center justify-center mx-auto mb-6 text-3xl font-bold text-white shadow-lg">
                2
              </div>
              <div className="text-5xl mb-4">📖</div>
              <h3 className="text-2xl font-bold text-gray-900 mb-4">Read</h3>
              <p className="text-gray-600 leading-relaxed">
                Your lecture becomes text — searchable, copyable, accessible from any browser.
              </p>
            </div>
            <div className="text-center p-8 bg-white rounded-2xl shadow-lg hover-lift border border-gray-100">
              <div className="w-20 h-20 bg-gradient-to-r from-cyan-500 to-blue-400 rounded-full flex items-center justify-center mx-auto mb-6 text-3xl font-bold text-white shadow-lg">
                3
              </div>
              <div className="text-5xl mb-4">🧠</div>
              <h3 className="text-2xl font-bold text-gray-900 mb-4">Understand</h3>
              <p className="text-gray-600 leading-relaxed">
                AI-powered summaries: key points, sections, and exam prep — coming soon!
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* Features */}
      <section className="py-20 bg-white">
        <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
          <h2 className="text-4xl lg:text-5xl font-bold text-gray-900 mb-12 text-center">
            Choose your plan
          </h2>
          <div className="grid md:grid-cols-2 gap-8">
            <div className="p-8 bg-gradient-to-br from-gray-50 to-white rounded-2xl border-2 border-gray-200 hover-lift">
              <div className="flex items-center justify-between mb-6">
                <h3 className="text-3xl font-bold text-gray-900">Free</h3>
                <span className="px-3 py-1 bg-green-100 text-green-700 rounded-full text-sm font-semibold">Forever</span>
              </div>
              <ul className="space-y-4 text-gray-600 mb-8">
                <li className="flex items-start gap-3">
                  <svg className="w-6 h-6 text-green-500 flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                  </svg>
                  <span className="text-lg">Unlimited recording</span>
                </li>
                <li className="flex items-start gap-3">
                  <svg className="w-6 h-6 text-green-500 flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                  </svg>
                  <span className="text-lg">Offline transcription</span>
                </li>
                <li className="flex items-start gap-3">
                  <svg className="w-6 h-6 text-green-500 flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                  </svg>
                  <span className="text-lg">Read on web</span>
                </li>
                <li className="flex items-start gap-3">
                  <svg className="w-6 h-6 text-green-500 flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                  </svg>
                  <span className="text-lg">Search &amp; copy</span>
                </li>
                <li className="flex items-start gap-3">
                  <svg className="w-6 h-6 text-green-500 flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                  </svg>
                  <span className="text-lg">Edit titles</span>
                </li>
              </ul>
            </div>
            <div className="p-8 bg-gradient-to-br from-blue-600 to-sky-600 rounded-2xl text-white shadow-2xl hover-lift relative overflow-hidden">
              <div className="absolute top-0 right-0 w-32 h-32 bg-white/10 rounded-full -mr-16 -mt-16"></div>
              <div className="absolute bottom-0 left-0 w-24 h-24 bg-white/10 rounded-full -ml-12 -mb-12"></div>
              <div className="relative z-10">
                <div className="flex items-center justify-between mb-6">
                  <h3 className="text-3xl font-bold">Pro</h3>
                  <span className="px-3 py-1 bg-yellow-400 text-yellow-900 rounded-full text-sm font-semibold">$2.99/mo</span>
                </div>
                <ul className="space-y-4 mb-8">
                  <li className="flex items-start gap-3">
                    <svg className="w-6 h-6 text-white flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                    </svg>
                    <span className="text-lg">Everything in Free</span>
                  </li>
                  <li className="flex items-start gap-3">
                    <svg className="w-6 h-6 text-white flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                    </svg>
                    <span className="text-lg">AI Summary</span>
                  </li>
                  <li className="flex items-start gap-3">
                    <svg className="w-6 h-6 text-white flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                    </svg>
                    <span className="text-lg">Key points extraction</span>
                  </li>
                  <li className="flex items-start gap-3">
                    <svg className="w-6 h-6 text-white flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                    </svg>
                    <span className="text-lg">Exam Mode (Q&amp;A, predictions)</span>
                  </li>
                  <li className="flex items-start gap-3">
                    <svg className="w-6 h-6 text-white flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                    </svg>
                    <span className="text-lg">Section breakdown</span>
                  </li>
                </ul>
                <ProCardUpgradeButton />
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Why lecsy */}
      <section className="bg-gradient-to-b from-white to-gray-50 py-20">
        <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
          <h2 className="text-4xl lg:text-5xl font-bold text-gray-900 mb-12 text-center">
            Why Lecsy Lecture Recording & AI Transcription App?
          </h2>
          <div className="grid md:grid-cols-3 gap-8">
            <div className="text-center p-8 bg-white rounded-2xl shadow-lg hover-lift">
              <div className="w-16 h-16 bg-gradient-to-r from-blue-500 to-sky-500 rounded-2xl flex items-center justify-center mx-auto mb-6">
                <svg className="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                </svg>
              </div>
              <h3 className="text-xl font-bold text-gray-900 mb-3">100% Local</h3>
              <p className="text-gray-600 leading-relaxed">
                Your voice never leaves your phone.
                <br />
                No cloud. No uploads. No privacy concerns.
              </p>
            </div>
            <div className="text-center p-8 bg-white rounded-2xl shadow-lg hover-lift">
              <div className="w-16 h-16 bg-gradient-to-r from-sky-500 to-cyan-500 rounded-2xl flex items-center justify-center mx-auto mb-6">
                <svg className="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M18.364 5.636a9 9 0 010 12.728m0 0l-2.829-2.829m2.829 2.829L21 21M15.536 8.464a5 5 0 010 7.072m0 0l-2.829-2.829m-4.243 2.829a4.978 4.978 0 01-1.414-2.83m-1.414 5.658a9 9 0 01-2.167-9.238m7.824 2.167a1 1 0 111.414 1.414m-1.414-1.414L3 3m8.293 8.293l1.414 1.414" />
                </svg>
              </div>
              <h3 className="text-xl font-bold text-gray-900 mb-3">Works Offline</h3>
              <p className="text-gray-600 leading-relaxed">
                Record and transcribe without internet.
                <br />
                Perfect for lecture halls with bad Wi-Fi.
              </p>
            </div>
            <div className="text-center p-8 bg-white rounded-2xl shadow-lg hover-lift">
              <div className="w-16 h-16 bg-gradient-to-r from-cyan-500 to-blue-400 rounded-2xl flex items-center justify-center mx-auto mb-6">
                <svg className="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
                </svg>
              </div>
              <h3 className="text-xl font-bold text-gray-900 mb-3">Built for Students</h3>
              <p className="text-gray-600 leading-relaxed">
                Designed around how students actually learn.
                <br />
                Not another productivity tool — a study companion.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* Pricing */}
      <section className="py-20 bg-white">
        <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8">
          <h2 className="text-4xl lg:text-5xl font-bold text-gray-900 mb-12 text-center">Pricing</h2>
          <div className="grid md:grid-cols-2 gap-8">
            <div className="border-2 border-gray-200 rounded-2xl p-8 hover-lift bg-white">
              <h3 className="text-2xl font-bold text-gray-900 mb-2">Free</h3>
              <p className="text-4xl font-bold text-gray-900 mb-2">$0 <span className="text-xl font-normal text-gray-600">/ forever</span></p>
              <ul className="space-y-4 mb-8 text-gray-600">
                <li className="flex items-start gap-3">
                  <svg className="w-6 h-6 text-green-500 flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                  </svg>
                  <span>Record unlimited lectures</span>
                </li>
                <li className="flex items-start gap-3">
                  <svg className="w-6 h-6 text-green-500 flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                  </svg>
                  <span>Transcribe on your iPhone</span>
                </li>
                <li className="flex items-start gap-3">
                  <svg className="w-6 h-6 text-green-500 flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                  </svg>
                  <span>Read on the web</span>
                </li>
                <li className="flex items-start gap-3">
                  <svg className="w-6 h-6 text-green-500 flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                  </svg>
                  <span>Search and copy anything</span>
                </li>
              </ul>
              <Link
                href="/login"
                className="block w-full text-center px-6 py-4 border-2 border-gray-900 text-gray-900 rounded-xl hover:bg-gray-900 hover:text-white transition-all font-semibold"
              >
                Get Started Free
              </Link>
            </div>
            <div className="border-2 border-blue-600 rounded-2xl p-8 hover-lift bg-gradient-to-br from-blue-50 to-sky-50 relative overflow-hidden">
              <div className="absolute top-4 right-4">
                <span className="px-3 py-1 bg-blue-600 text-white rounded-full text-xs font-semibold">POPULAR</span>
              </div>
              <h3 className="text-2xl font-bold text-gray-900 mb-2">Pro</h3>
              <p className="text-4xl font-bold text-gray-900 mb-2">$2.99 <span className="text-xl font-normal text-gray-600">/ month</span></p>
              <ul className="space-y-4 mb-8 text-gray-600">
                <li className="flex items-start gap-3">
                  <svg className="w-6 h-6 text-blue-600 flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                  </svg>
                  <span>Everything in Free</span>
                </li>
                <li className="flex items-start gap-3">
                  <svg className="w-6 h-6 text-blue-600 flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                  </svg>
                  <span>AI-powered summaries</span>
                </li>
                <li className="flex items-start gap-3">
                  <svg className="w-6 h-6 text-blue-600 flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                  </svg>
                  <span>Exam prep mode</span>
                </li>
                <li className="flex items-start gap-3">
                  <svg className="w-6 h-6 text-blue-600 flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                  </svg>
                  <span>Key points &amp; sections</span>
                </li>
              </ul>
              <ProCardUpgradeButton />
            </div>
          </div>
        </div>
      </section>

      {/* FAQ */}
      <section className="bg-gray-50 py-20">
        <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
          <h2 className="text-4xl lg:text-5xl font-bold text-gray-900 mb-12 text-center">FAQ</h2>
          <div className="space-y-6">
            <div className="bg-white p-6 rounded-xl shadow-md hover-lift">
              <h3 className="text-xl font-bold text-gray-900 mb-3">Is my data safe?</h3>
              <p className="text-gray-600 leading-relaxed">
                Yes. Audio never leaves your device. Only text is saved to the cloud — and only when you choose to.
              </p>
            </div>
            <div className="bg-white p-6 rounded-xl shadow-md hover-lift">
              <h3 className="text-xl font-bold text-gray-900 mb-3">Do I need internet to record?</h3>
              <p className="text-gray-600 leading-relaxed">
                No. Recording and transcription work completely offline.
              </p>
            </div>
            <div className="bg-white p-6 rounded-xl shadow-md hover-lift">
              <h3 className="text-xl font-bold text-gray-900 mb-3">What languages are supported?</h3>
              <p className="text-gray-600 leading-relaxed">
                Japanese and English. Auto-detection is available.
              </p>
            </div>
            <div className="bg-white p-6 rounded-xl shadow-md hover-lift">
              <h3 className="text-xl font-bold text-gray-900 mb-3">How do I upgrade to Pro?</h3>
              <p className="text-gray-600 leading-relaxed">
                Simply log in to your account and click "Upgrade to Pro" on the dashboard. You'll be redirected to a secure checkout page powered by Stripe.
              </p>
            </div>
            <div className="bg-white p-6 rounded-xl shadow-md hover-lift">
              <h3 className="text-xl font-bold text-gray-900 mb-3">Can I cancel my Pro subscription?</h3>
              <p className="text-gray-600 leading-relaxed">
                Yes! You can cancel your Pro subscription anytime from the dashboard. Your subscription will remain active until the end of the current billing period.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* Final CTA */}
      <section className="py-20 bg-gradient-to-br from-blue-600 via-sky-600 to-blue-500 text-white relative overflow-hidden">
        <div className="absolute inset-0 bg-grid-pattern opacity-10"></div>
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 text-center relative z-10">
          <h2 className="text-4xl lg:text-5xl font-bold mb-6">
            Start capturing your lectures today with Lecsy.
          </h2>
          <p className="text-xl mb-4 opacity-90">
            Free lecture recording & AI transcription app. No account required to start.
          </p>
          <p className="text-xl mb-4 opacity-90">
            Start recording in seconds.
          </p>
          <p className="text-xl mb-8 opacity-90">
            Just open the app and hit record.
          </p>
          <Link
            href="/login"
            className="inline-flex items-center gap-2 px-8 py-4 bg-white text-blue-600 rounded-xl text-lg font-semibold hover:bg-gray-100 transition-all shadow-2xl hover:shadow-3xl transform hover:scale-105"
          >
            Download Lecsy — Free
            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 7l5 5m0 0l-5 5m5-5H6" />
            </svg>
          </Link>
        </div>
      </section>

      {/* Footer */}
      <footer className="border-t border-gray-200 py-8 bg-white">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex flex-col md:flex-row justify-between items-center text-gray-600 text-sm">
            <div className="mb-4 md:mb-0">© 2026 lecsy. All rights reserved.</div>
            <div className="flex gap-6">
              <Link href="/privacy" className="hover:text-gray-900 transition-colors">Privacy Policy</Link>
              <Link href="/terms" className="hover:text-gray-900 transition-colors">Terms of Service</Link>
            </div>
          </div>
        </div>
      </footer>
    </main>
  );
}
