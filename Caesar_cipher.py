# --- Розшифрувач шифру Цезаря ---


def decrypt_caesar(ciphertext, key, alphabet):
    """
    Розшифровує текст за допомогою шифру Цезаря.
    
    Args:
        ciphertext (str): Зашифрований текст.
        key (int): Ключ для зсуву (для розшифрування).
        alphabet (str): Алфавіт, що використовується для шифрування.
    
    Returns:
        str: Розшифрований текст.
    """
    plaintext = ""
    alphabet_len = len(alphabet)
    

    for char in ciphertext:
        if char in alphabet:
            
            current_index = alphabet.find(char)
            new_index = (current_index - key) % alphabet_len
            
            plaintext += alphabet[new_index]
        else:
            plaintext += char
            
    return plaintext

# --- Основна частина програми ---
if __name__ == "__main__":
    
    ukr_letters = 'абвгґдеєжзиіїйклмнопрстуфхцчшщьюя'
    KEY = 15
    encrypted_message = "кщіа всльцфлжцй нлуща бакгяхґх — црск баолял."
    
    print(f"Алфавіт: {ukr_letters} (Довжина: {len(ukr_letters)})")
    print(f"Ключ: {KEY}")
    print(f"Зашифроване повідомлення: {encrypted_message}")
    
    decrypted_message = decrypt_caesar(encrypted_message, KEY, ukr_letters)
    
    print("-" * 40)
    print(f"Розшифроване повідомлення: {decrypted_message}")