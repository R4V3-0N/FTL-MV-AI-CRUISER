import random

file = open("names.xml", "w")

nouns = ['Class', 'Agent', 'Trojan', 'Turret', 'Injector', 'Intruder', 'Drive', 'Scraper', 'Object', 'Address']
letters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
nums = '1234567890'

def alphanum(count):
    ret = ''
    for _ in range(count):
        if random.randrange(2) == 0:
            ret += random.choice(letters)
        else:
            ret += random.choice(nums)
    return ret

for _ in range(50):
    name = random.choice(nouns) + ' '
    select = random.randrange(10)
    if select < 2:
        name += alphanum(2) + '-' + alphanum(2)
    elif select < 6:
        name += alphanum(4)
    else:
        name += alphanum(5)
    file.writelines([
        '<event>\n',
        '    <text>A new hologram coalesces aboard your ship, ready to serve.</text>\n',
        '    <variable name="loc_holos_dead" op="add" val="-1"/>\n',
        f'    <crewMember amount="1" class="rvs_ai_hologram">{name}</crewMember>\n',
        '</event>\n'
    ])

file.close()
