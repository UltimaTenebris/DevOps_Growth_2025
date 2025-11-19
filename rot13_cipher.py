# --- Шифр ROT13 ---
# ROT13 - це спеціальний випадок шифру Цезаря, де
# ключ = 13, а алфавіт = латинський.

def apply_rot13(text):
    lower_alphabet = 'abcdefghijklmnopqrstuvwxyz'
    upper_alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    
    key = 13
    result_text = ""
    
    for char in text:
        if char in lower_alphabet:
            current_index = lower_alphabet.find(char)
            new_index = (current_index + key) % 26
            result_text += lower_alphabet[new_index]
            
        elif char in upper_alphabet:
            current_index = upper_alphabet.find(char)
            new_index = (current_index + key) % 26
            result_text += upper_alphabet[new_index]
            
        else:
            result_text += char
            
    return result_text


if __name__ == "__main__":
    
    original_message = "Hello, this is a secret message!"
    
    print("Демонстрація ROT13")
    print(f"Оригінальне повідомлення: {original_message}")
    
    encrypted_message = apply_rot13(original_message)
    print(f"Зашифроване (ROT13):     {encrypted_message}")
    
    decrypted_message = apply_rot13(encrypted_message)
    print(f"Розшифроване (ROT13):     {decrypted_message}")
    
    print("-" * 40)
    if decrypted_message == original_message:
        print("Успіх! ROT13, застосований двічі, повернув оригінал.")
    else:
        print("Помилка!")