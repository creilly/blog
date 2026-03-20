import math

patm = 1e+3 # mbar
p4p = 6.e-8 # mbar
p4s = 625 # liters / sec
cosexp = 12.0
abs_dia = 4.0 # mm
abs_thk = 0.1 # mm
surf_bolo_dist = 80.0 # mm

bolos = 95.0 # liters per sec per inch**2

mmperinch = 25.4 # mm / inch
vstp = 22.4 # liters per mole

c_ch4_high = 0.5 # cal / mol / deg K (in equilibrium)
c_ch4_low = 1e-2 # cal / mol / deg K (out of equilibrium)
c_diamond = 3.2e-7 # cal / mol / deg K

n_diamond = 3.0e-3 # grams / mm**3

m_diamond = 12 # grams per mole

# moles / sec
def bolo_flux():
    return (cosexp + 1)/(2. * math.pi)*input_flux()*(
        math.pi*(abs_dia/2)**2/surf_bolo_dist**2
    )

# moles / sec
def input_flux():
    return p4p / patm * p4s / vstp

# moles / sec
def bg_flux():
    return bolos / vstp * p4p / patm * math.pi * (abs_dia/2/mmperinch)**2

# moles
def absorber_size():
    return math.pi * (abs_dia/2)**2 * abs_thk * n_diamond / m_diamond

def efmt(f): return '{:.2e}'.format(f)

LOW, HIGH = 0, 1
# seconds
def bolo_lifetime(c_code):
    return c_diamond * absorber_size() / bolo_flux() / {
        LOW:c_ch4_low,HIGH:c_ch4_high
    }[c_code]

print('bolo flux:',efmt(bolo_flux()),'moles / sec')
print('input flux:',efmt(input_flux()),'moles / sec')
print('bg flux:',efmt(bg_flux()),'moles / sec')
print('diamond size:',efmt(absorber_size()),'moles')
print('long bolo lifetime:',efmt(bolo_lifetime(LOW)),'sec')
print('short bolo lifetime:',efmt(bolo_lifetime(HIGH)),'sec')