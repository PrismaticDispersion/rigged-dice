import random

numbers = [str(random.randint(1, 13)) for _ in range(20)]

print("numbers = [")
for n in numbers:
    print(f'    "{n}",')
print("];")
