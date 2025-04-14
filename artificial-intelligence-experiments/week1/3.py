def ReverseKeyValue(dict):
    return { v: k for k, v in dict.items() }

dict = { "a": 1, "b": 2, "c": 3 }

print(ReverseKeyValue(dict))
