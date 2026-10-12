import React, { useState, useEffect } from 'react'
import { fetchServices, createBooking, supabase } from './lib/supabase'
import { Settings, Calendar, Phone, Instagram, Send, Loader2 } from 'lucide-react'

const DEFAULT_SERVICES = [
  { id: '1', title: 'کوچ', description: 'جلسات کوچینگ هدفمند برای رشد شخصی و کسب‌وکار', icon: '🎯' },
  { id: '2', title: 'مشاوره', description: 'آنالیز و استراتژی تخصصی کسب‌وکار', icon: '💬' },
  { id: '3', title: 'برنامه', description: 'طراحی برنامه اجرایی سفارشی', icon: '📋' }
]

export default function App() {
  const [services, setServices] = useState(DEFAULT_SERVICES)
  const [showBooking, setShowBooking] = useState(false)
  const [selectedService, setSelectedService] = useState(null)
  const [step, setStep] = useState(1)
  const [form, setForm] = useState({
    full_name: '', phone: '', email: '', business_type: '', business_name: '',
    channel_id: '', is_urgent: false, notes: '', sessions: '3', consult_type: 'chat'
  })
  const [loading, setLoading] = useState(false)
  const [result, setResult] = useState(null)
  const [slogan, setSlogan] = useState('تحلیل حرفه‌ای کسب‌وکار برای رشد پایدار و هوشمند')

  useEffect(() => {
    fetchServices().then(setServices).catch(() => {})
  }, [])

  const openBooking = (svc) => {
    setSelectedService(svc)
    setShowBooking(true)
    setStep(1)
    setResult(null)
  }

  const handleSubmit = async () => {
    if (!form.full_name || !form.phone) return alert('نام و شماره تماس الزامی است')
    setLoading(true)
    try {
      const payload = {
        p_service_id: selectedService?.id || services[0]?.id,
        p_full_name: form.full_name,
        p_phone: form.phone,
        p_email: form.email,
        p_business_type: form.business_type,
        p_business_name: form.business_name,
        p_channel_id: form.channel_id,
        p_is_urgent: form.is_urgent,
        p_form_answers: { notes: form.notes, sessions: form.sessions }
      }
      const res = await createBooking(payload)
      setResult(res)
    } catch (e) {
      setResult({ success: false, error: e.message || 'خطا در ثبت رزرو' })
    }
    setLoading(false)
  }

  return (
    <div className="min-h-screen">
      {/* Header */}
      <header className="fixed top-0 left-0 right-0 z-50 flex justify-between items-center px-4 py-3 bg-black/60 backdrop-blur-md border-b border-gray-800">
        <button className="flex items-center gap-2 text-sm hover:text-luxury-lightblue group" title="مدیریت">
          <Settings className="w-5 h-5 group-hover:rotate-90 transition-transform duration-500" />
          <span className="hidden sm:inline">مدیریت</span>
        </button>
        <button className="flex items-center gap-2 text-sm bg-luxury-blue/20 px-3 py-1.5 rounded-full hover:bg-luxury-blue/40">
          <Calendar className="w-4 h-4" />
          نمایش وضعیت نوبت‌ها
        </button>
      </header>

      {/* Hero with Video */}
      <section className="relative h-[70vh] md:h-screen flex items-center justify-center overflow-hidden">
        <video
          autoPlay muted loop playsInline
          className="absolute inset-0 w-full h-full object-cover opacity-60"
          poster="/logo.png"
        >
          <source src="/hero.mp4" type="video/mp4" />
        </video>
        <div className="absolute inset-0 bg-gradient-to-b from-black/40 via-transparent to-black" />
        <div className="relative z-10 text-center px-4">
          <img src="/logo.png" alt="TAHA" className="w-32 md:w-48 mx-auto mb-6 drop-shadow-2xl" />
          <h1 className="text-3xl md:text-5xl font-bold mb-4">TAHA</h1>
          <p className="text-lg md:text-2xl text-gray-300 max-w-2xl mx-auto">{slogan}</p>
        </div>
      </section>

      {/* Slogan + CTAs */}
      <section className="py-12 px-4 text-center bg-black">
        <p className="text-xl md:text-2xl mb-8 text-luxury-lightblue">{slogan}</p>
        <div className="flex flex-col sm:flex-row gap-4 justify-center">
          <button onClick={() => document.getElementById('contact').scrollIntoView({behavior:'smooth'})} className="btn-outline">تماس با ما</button>
          <button onClick={() => document.getElementById('services').scrollIntoView({behavior:'smooth'})} className="btn-primary">مشاهده خدمات</button>
          <button onClick={() => openBooking(services[0])} className="btn-primary bg-luxury-green hover:bg-green-700">رزرو نوبت</button>
        </div>
      </section>

      {/* Experience */}
      <section className="py-16 px-4 flex flex-col md:flex-row items-center justify-center gap-8 bg-gradient-to-r from-black to-gray-900">
        <div className="text-center">
          <h2 className="text-4xl font-bold text-luxury-gold">+2 سال تجربه</h2>
          <p className="text-gray-400 mt-2">در آنالیز و رشد کسب‌وکار</p>
        </div>
        <div className="w-64 h-40 bg-gray-900 rounded-2xl border border-gray-700 flex items-center justify-center">
          <span className="text-gray-500">نمودار رشد مفهومی</span>
        </div>
      </section>

      {/* Services */}
      <section id="services" className="py-16 px-4">
        <h2 className="text-3xl font-bold text-center mb-10">خدمات</h2>
        <div className="flex overflow-x-auto snap-x snap-mandatory gap-6 pb-4 px-2 md:justify-center">
          {services.slice(0, 3).map(s => (
            <div key={s.id} onClick={() => openBooking(s)} className="luxury-card min-w-[280px] snap-center p-6 cursor-pointer hover:scale-105 transition-transform">
              <div className="text-4xl mb-4">{s.icon}</div>
              <h3 className="text-xl font-bold mb-2">{s.title}</h3>
              <p className="text-gray-400 text-sm">{s.description}</p>
              <button className="mt-4 text-luxury-lightblue text-sm">رزرو این خدمت</button>
            </div>
          ))}
          {services.length > 3 && (
            <div className="luxury-card min-w-[280px] snap-center p-6 flex items-center justify-center">
              <span>مشاهده همه خدمات</span>
            </div>
          )}
        </div>
      </section>

      {/* Contact */}
      <section id="contact" className="py-16 px-4 bg-gray-950 text-center">
        <h2 className="text-3xl font-bold mb-8">تماس با ما</h2>
        <div className="flex flex-col md:flex-row gap-6 justify-center items-center">
          <a href="tel:09918760129" className="flex items-center gap-2 hover:text-luxury-lightblue">
            <Phone className="w-5 h-5" /> 09918760129
          </a>
          <a href="https://instagram.com" className="flex items-center gap-2 hover:text-pink-400">
            <Instagram className="w-5 h-5" /> اینستاگرام
          </a>
          <a href="https://t.me" className="flex items-center gap-2 hover:text-sky-400">
            <Send className="w-5 h-5" /> تلگرام
          </a>
        </div>
      </section>

      {/* Booking Modal */}
      {showBooking && (
        <div className="fixed inset-0 z-[100] bg-black/80 flex items-center justify-center p-4" onClick={() => setShowBooking(false)}>
          <div className="bg-gray-900 border border-gray-700 rounded-2xl max-w-lg w-full max-h-[90vh] overflow-y-auto p-6" onClick={e => e.stopPropagation()}>
            <div className="flex justify-between items-center mb-4">
              <h3 className="text-xl font-bold">رزرو نوبت {selectedService?.title}</h3>
              <button onClick={() => setShowBooking(false)} className="text-2xl">&times;</button>
            </div>
            {loading && <div className="flex justify-center py-8"><Loader2 className="animate-spin w-8 h-8 text-luxury-blue" /></div>}
            {!loading && !result && (
              <>
                {step === 1 && (
                  <div className="space-y-4">
                    <input className="w-full bg-black border border-gray-700 rounded-xl p-3" placeholder="نام و نام خانوادگی *" value={form.full_name} onChange={e => setForm({...form, full_name: e.target.value})} />
                    <input className="w-full bg-black border border-gray-700 rounded-xl p-3" placeholder="شماره تماس *" value={form.phone} onChange={e => setForm({...form, phone: e.target.value})} />
                    <input className="w-full bg-black border border-gray-700 rounded-xl p-3" placeholder="ایمیل (برای دسترسی به پنل)" type="email" value={form.email} onChange={e => setForm({...form, email: e.target.value})} />
                    <select className="w-full bg-black border border-gray-700 rounded-xl p-3" value={form.business_type} onChange={e => setForm({...form, business_type: e.target.value})}>
                      <option value="">نوع کسب‌وکار</option>
                      <option>آنلاین‌شاپ</option><option>فروش دوره آموزشی</option><option>خدمات</option>
                      <option>فروشگاه فیزیکی</option><option>شخصی/برند</option><option>سایر</option>
                    </select>
                    <input className="w-full bg-black border border-gray-700 rounded-xl p-3" placeholder="نام کسب‌وکار" value={form.business_name} onChange={e => setForm({...form, business_name: e.target.value})} />
                    <label className="flex items-center gap-3 cursor-pointer">
                      <div className={`w-12 h-6 rounded-full relative transition-colors ${form.is_urgent ? 'bg-luxury-green' : 'bg-gray-600'}`} onClick={() => setForm({...form, is_urgent: !form.is_urgent})}>
                        <div className={`absolute top-0.5 w-5 h-5 rounded-full bg-white transition-all ${form.is_urgent ? 'right-0.5' : 'left-0.5'}`} />
                      </div>
                      <span>عجله دارم (ممکن است هزینه اضافه داشته باشد)</span>
                    </label>
                    <button onClick={() => setStep(2)} className="btn-primary w-full">بعدی</button>
                  </div>
                )}
                {step === 2 && (
                  <div className="space-y-4">
                    <p className="text-sm text-gray-400">فیلدهای اختصاصی خدمت {selectedService?.title}</p>
                    <textarea className="w-full bg-black border border-gray-700 rounded-xl p-3" placeholder="توضیحات" rows={4} value={form.notes} onChange={e => setForm({...form, notes: e.target.value})} />
                    <div className="flex gap-2">
                      <button onClick={() => setStep(1)} className="btn-outline flex-1">بازگشت</button>
                      <button onClick={handleSubmit} className="btn-primary flex-1">رزرو نوبت</button>
                    </div>
                  </div>
                )}
              </>
            )}
            {result && (
              <div className="text-center py-6">
                {result.success ? (
                  <>
                    <p className="text-luxury-green text-lg mb-2">رزرو با موفقیت ثبت شد</p>
                    <p>کد پیگیری: <strong>{result.tracking_code}</strong></p>
                    <p className="text-sm text-gray-400 mt-2">وضعیت: در صف انتظار</p>
                  </>
                ) : (
                  <p className="text-red-400">{result.error}</p>
                )}
                <button onClick={() => setShowBooking(false)} className="btn-primary mt-4">بستن</button>
              </div>
            )}
          </div>
        </div>
      )}

      <footer className="py-6 text-center text-gray-500 text-sm border-t border-gray-800">
        © {new Date().getFullYear()} TAHA Campaign Writer
      </footer>
    </div>
  )
}
