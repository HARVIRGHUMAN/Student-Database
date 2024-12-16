#!/bin/bash

#Nicholas Gaither
#Victor Castellanos
#Harvir Ghuman

# Use a persistent directory
REPL_HOME="/home/runner/${REPL_SLUG}"
DB_NAME="$REPL_HOME/school.db"
LOG_FILE="$REPL_HOME/script.log"
BACKUP_DIR="$REPL_HOME/backups"
mkdir -p "$BACKUP_DIR"

# creates logs of anything happening in the database
log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# creates a backup of the database 
backup_database() {
    local backup_file="$BACKUP_DIR/school_$(date '+%Y%m%d_%H%M%S').db"
    cp "$DB_NAME" "$backup_file"
    log_action "Database backed up to $backup_file"
}

init_database() {
    # Ensure the directory exists
    mkdir -p "$REPL_HOME"

    sqlite3 $DB_NAME <<EOF
CREATE TABLE IF NOT EXISTS grades (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    student_name TEXT NOT NULL,
    course_name TEXT,
    course_number TEXT,
    course_subject TEXT,
    professor TEXT,
    grade TEXT
);
EOF
    log_action "Database initialized"
}

#  uses python file to validate  subject input
get_subject() {
    while true; do
        read -p "Enter course subject (4 letters or less): " subject
        result=$(python3 validate_input.py "$subject" 2>&1)
        if [[ "$result" != "Invalid" ]]; then
            echo $result
            return
        fi
    done
}

#  using perl file to validate grade input
validate_grade() {
    grade=$1
    if result=$(perl validate_grade.pl "$grade" 2>&1); then
        return
    else
        echo -e "\e[31mInvalid grade. Please enter a valid grade (A, B, C, D, F, or NA).\e[0m"
        return 1
    fi
}

# function that adds students to the database along with their grades
add_grades() {
    echo -e "\n===== Add Grades =====\n"
    read -p "Enter student name: " student_name

    # Check if student_name is not empty
    if [[ -z "$student_name" ]]; then
        echo -e "\e[31mError: Student name cannot be empty.\e[0m"
        log_action "Failed to add grade: Student name was empty"
        return
    fi

    echo ""
    while true; do
        read -p "Enter course name (or 'done' to finish): " course_name
        [[ $course_name == "done" ]] && break

        read -p "Enter course number: " course_number
        course_subject=$(get_subject)
        read -p "Enter professor name: " professor

        while true; do
            read -p "Enter course grade (or NA if not received): " grade
            if validate_grade "$grade"; then
                break
            fi
        done

        sqlite3 $DB_NAME "INSERT INTO grades (student_name, course_name, course_number, course_subject, professor, grade) VALUES ('$student_name', '$course_name', '$course_number', '$course_subject', '$professor', '$grade');"
        if [[ $? -eq 0 ]]; then
            echo -e "\e[32mGrade added successfully.\e[0m\n"
            log_action "Added grade for $student_name in $course_name"
        else
            echo -e "\e[31mError: Could not add grade. Please try again.\e[0m"
            log_action "Failed to add grade for $student_name in $course_name"
        fi
    done
    echo -e "\nAll grades added successfully.\n"
}

# functions that prompts user for student name and displays their data
view_student_data() {
    echo -e "\n===== View Student Data =====\n"
    read -p "Enter student name: " student_name
    echo -e "\nStudent Information:\n"
    sqlite3 $DB_NAME <<EOF
.headers on
.mode column
SELECT student_name AS "Student Name",
       course_name AS "Course Name",
       course_number AS "Course Number",
       course_subject AS "Course Subject", 
       professor AS "Professor", 
       grade AS "Grade"
FROM grades
WHERE student_name = '$student_name';
EOF

    echo ""
    sqlite3 $DB_NAME <<EOF 
.headers on
.mode column
SELECT ROUND(AVG(CASE 
    WHEN grade = 'A' THEN 4.0
    WHEN grade = 'B' THEN 3.0
    WHEN grade = 'C' THEN 2.0
    WHEN grade = 'D' THEN 1.0
    WHEN grade = 'F' THEN 0.0
    ELSE NULL
END), 2) AS GPA
FROM grades
WHERE student_name = '$student_name' AND grade != 'NA';
EOF
    echo ""
    log_action "Viewed data for $student_name"
}
# function that edits student name, course grade or deletes course from database
edit_student_data() {
    echo -e "\n===== Edit Student Data =====\n"
    read -p "Enter student name: " student_name
    echo -e "\n1. Edit student name"
    echo "2. Edit course grade"
    echo "3. Delete course from record"
    read -p "Choose an option (1, 2 or 3): " edit_option

    case $edit_option in
        1)
            read -p "Enter new student name: " new_name
            sqlite3 $DB_NAME "UPDATE grades SET student_name = '$new_name' WHERE student_name = '$student_name';"
            if [[ $? -eq 0 ]]; then
                echo -e "\e[32mStudent name updated successfully.\e[0m\n"
                log_action "Updated name from $student_name to $new_name"
            else
                echo -e "\e[31mError: Could not update student name. Please try again.\e[0m"
                log_action "Failed to update student name from $student_name to $new_name"
            fi
            ;;
        2)
            echo -e "\nCurrent grades:\n"
            sqlite3 $DB_NAME "SELECT id, course_name, grade FROM grades WHERE student_name = '$student_name';"
            echo ""
            read -p "Enter grade ID to edit: " grade_id
            read -p "Enter new grade: " new_grade
            if [[ $new_grade =~ ^[ABCDF]$ ]]; then
                sqlite3 $DB_NAME "UPDATE grades SET grade = '$new_grade' WHERE id = $grade_id AND student_name = '$student_name';"
                if [[ $? -eq 0 ]]; then
                    echo -e "\e[32mGrade updated successfully.\e[0m\n"
                    log_action "Updated grade ID $grade_id for $student_name to $new_grade"
                else
                    echo -e "\e[31mError: Could not update grade. Please try again.\e[0m"
                    log_action "Failed to update grade ID $grade_id for $student_name to $new_grade"
                fi
            else
                echo -e "\e[31mInvalid grade. Please enter a valid grade (A, B, C, D, or F).\e[0m"
            fi
            ;;
        3) 
            echo -e "\nCurrent courses:\n"
            sqlite3 $DB_NAME "SELECT id, course_name FROM grades WHERE student_name = '$student_name';"
            echo ""
            read -p "Enter course ID to delete: " course_id
            echo -e "\nAre you sure you want to delete course ID $course_id for $student_name? This action cannot be undone."
            read -p "Type 'YES' to confirm: " confirmation
            if [ "$confirmation" = "YES" ]; then
                sqlite3 $DB_NAME "DELETE FROM grades WHERE id = $course_id AND student_name = '$student_name';"
                if [[ $? -eq 0 ]]; then
                    echo -e "\e[32mCourse deleted successfully.\e[0m\n"
                    log_action "Deleted course ID $course_id for $student_name"
                else
                    echo -e "\e[31mError: Could not delete course. Please try again.\e[0m"
                    log_action "Failed to delete course ID $course_id for $student_name"
                fi
            else
                echo -e "\e[31mDeletion cancelled.\e[0m\n"
            fi
            ;;
        *)
            echo -e "\n\e[31mInvalid option. Please try again.\e[0m\n"
            ;;
    esac
}

#removes student from database
remove_student() {
    echo -e "\n===== Remove Student =====\n"
    read -p "Enter student name to remove: " student_name
    echo -e "\nAre you sure you want to remove $student_name and all associated grades? This action cannot be undone."
    read -p "Type 'YES' to confirm: " confirmation
    if [ "$confirmation" = "YES" ]; then
        sqlite3 $DB_NAME "DELETE FROM grades WHERE student_name = '$student_name';"
        if [[ $? -eq 0 ]]; then
            echo -e "\e[32mStudent $student_name and all associated grades have been removed.\e[0m\n"
            log_action "Removed student $student_name"
        else
            echo -e "\e[31mError: Could not remove student. Please try again.\e[0m"
            log_action "Failed to remove student $student_name"
        fi
    else
        echo -e "\e[31mRemoval cancelled.\e[0m\n"
    fi
}

# lists all students
list_students() {
    echo -e "\n===== List of All Students =====\n"
    sqlite3 $DB_NAME "SELECT DISTINCT student_name FROM grades ORDER BY student_name;" | ./list_students.awk
    echo ""
}
# lists student all student
#list_students() {
#    echo -e "\n===== List of All Students =====\n"
#    sqlite3 $DB_NAME "SELECT DISTINCT student_name FROM grades ORDER BY student_name;" | awk '{print $1, $2}'
#    echo ""
#}


# Exports data to a CSV file
export_data() {
    echo -e "\n===== Export Data =====\n"
    read -p "Enter filename to export to (without extension): " filename
    local filepath="$REPL_HOME/${filename}.csv"
    sqlite3 $DB_NAME "SELECT * FROM grades;" -csv > "$filepath"
    echo -e "\e[32mData exported to $filepath successfully.\e[0m"
    log_action "Exported data to $filepath"
}

# imports data from a CSV file to database
import_data() {
    echo -e "\n===== Import Data =====\n"
    read -p "Enter filename to import from (with .csv extension): " filename
    local filepath="$REPL_HOME/$filename"
    if [ -f "$filepath" ]; then
        backup_database
        sqlite3 $DB_NAME <<EOF
.mode csv
.import $filepath grades
EOF
        echo -e "\e[32mData imported from $filepath successfully.\e[0m"
        log_action "Imported data from $filepath"
    else
echo -e "\e[31mFile not found: $filepath. Please ensure the file exists and try again.\e[0m"
        log_action "Failed to import data from $filepath - file not found"
    fi
}

# Displays menu to search through data base, by student name, course subject, by grade
search_and_filter() {
    echo -e "\n===== Search and Filter =====\n"
    echo "1. Search by student name"
    echo "2. Filter by course subject"
    echo "3. Filter by grade"
    read -p "Choose an option (1-3): " search_option

    case $search_option in
        1)
            read -p "Enter student name to search: " student_name
            sqlite3 $DB_NAME <<EOF
.headers on
.mode column
SELECT student_name AS "Student Name",
       course_name AS "Course Name",
       course_number AS "Course Number",
       course_subject AS "Course Subject", 
       professor AS "Professor", 
       grade AS "Grade"
FROM grades
WHERE student_name LIKE '%$student_name%';
EOF
            log_action "Searched for student name containing '$student_name'"
            ;;
        2)
            read -p "Enter course subject to filter: " course_subject
            sqlite3 $DB_NAME <<EOF
.headers on
.mode column
SELECT student_name AS "Student Name",
       course_name AS "Course Name",
       course_number AS "Course Number",
       course_subject AS "Course Subject", 
       professor AS "Professor", 
       grade AS "Grade"
FROM grades
WHERE course_subject = '$course_subject';
EOF
            log_action "Filtered records by course subject '$course_subject'"
            ;;
        3)
            read -p "Enter grade to filter (A, B, C, D, F): " grade
            if [[ $grade =~ ^[ABCDF]$ ]]; then
                sqlite3 $DB_NAME <<EOF
.headers on
.mode column
SELECT student_name AS "Student Name",
       course_name AS "Course Name",
       course_number AS "Course Number",
       course_subject AS "Course Subject", 
       professor AS "Professor", 
       grade AS "Grade"
FROM grades
WHERE grade = '$grade';
EOF
                log_action "Filtered records by grade '$grade'"
            else
                echo -e "\e[31mInvalid grade. Please enter a valid grade (A, B, C, D, F).\e[0m"
            fi
            ;;
        *)
            echo -e "\e[31mInvalid option. Please try again.\e[0m"
            ;;
    esac
}

# main menu display that keeps looping until closed
main_menu() {
    while true; do
        echo -e "\n==============================="
        echo "         Student Database        "
        echo -e "===============================\n"
        echo "1. Add grades for a student"
        echo "2. View student data"
        echo "3. Edit student data"
        echo "4. Remove a student"
        echo "5. List all students"
        echo "6. Export data to CSV"
        echo "7. Import data from CSV"
        echo "8. Search and filter data"
        echo -e "9. Exit\n"
        read -p "Choose an option (1-9): " option

        case $option in
            1) add_grades ;;
            2) view_student_data ;;
            3) edit_student_data ;;
            4) remove_student ;;
            5) list_students ;;
            6) export_data ;;
            7) import_data ;;
            8) search_and_filter ;;
            9) echo -e "\nExiting...\n"; log_action "Script exited"; exit 0 ;;
            *) echo -e "\n\e[31mInvalid option. Please try again.\e[0m\n" ;;
        esac
    done
}

# Initialize the database and start the main menu
init_database
main_menu