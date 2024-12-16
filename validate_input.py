import re
import sys

def validate_subject(subject):
    if re.match(r"^[A-Za-z]{1,4}$", subject):
        print(subject)
    else:
        print("Invalid", file=sys.stderr)

if __name__ == "__main__":
    subject = sys.argv[1]
    validate_subject(subject)