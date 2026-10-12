import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://crmmovbbrnbizgzofzgj.supabase.co'
const supabaseKey = 'sb_publishable_IX-jdavkBcPbM6HplFq6kQ_Qe1ekP0h' // publishable only

export const supabase = createClient(supabaseUrl, supabaseKey)

export async function fetchServices() {
  const { data, error } = await supabase
    .from('services')
    .select('*')
    .eq('is_active', true)
    .order('display_order')
  if (error) throw error
  return data
}

export async function createBooking(payload) {
  const { data, error } = await supabase.rpc('create_booking_atomic', payload)
  if (error) throw error
  return data
}
