const { v4: uuidv4 } = require('uuid');

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> } 
 */
exports.seed = async function(knex) {
  // Get class and teacher IDs from previous seeds
  const classes = await knex('classes').select('id').limit(3);
  const teachers = await knex('users').where('user_type', 'teacher').select('id').limit(2);
  
  if (classes.length === 0 || teachers.length === 0) {
    console.log('No classes or teachers found. Make sure to run previous seeds first.');
    return;
  }

  // Use the same class IDs as in the class seeds
  const mathClassId = '550e8400-e29b-41d4-a716-446655440001';
  const scienceClassId = '550e8400-e29b-41d4-a716-446655440002';
  const englishClassId = '550e8400-e29b-41d4-a716-446655440003';
  const teacher1Id = teachers[0].id;
  const teacher2Id = teachers[1].id;

  // Clear existing class updates
  await knex('class_updates').del();

  // Create predefined update IDs for easy reference
  const update1Id = uuidv4();
  const update2Id = uuidv4();
  const update3Id = uuidv4();
  const update4Id = uuidv4();
  const update5Id = uuidv4();
  const update6Id = uuidv4();
  const update7Id = uuidv4();
  const update8Id = uuidv4();
  const update9Id = uuidv4();
  const update10Id = uuidv4();

  // Insert class updates
  await knex('class_updates').insert([
    // Mathematics Class Updates
    {
      id: update1Id,
      class_id: mathClassId,
      author_id: teacher1Id,
      title: 'Welcome to Mathematics 5A!',
      content: 'Welcome to our mathematics class! This year we will be covering fractions, decimals, geometry, and basic algebra. Please make sure to bring your textbook, notebook, and calculator to every class. If you have any questions, feel free to ask during class or visit me during office hours.',
      update_type: 'announcement',
      attachments: JSON.stringify([
        {
          fileName: 'Class Syllabus.pdf',
          fileUrl: '/uploads/syllabus_math_5a.pdf',
          fileType: 'application/pdf',
          fileSize: 245760
        },
        {
          fileName: 'Supply List.pdf',
          fileUrl: '/uploads/supply_list_math.pdf',
          fileType: 'application/pdf',
          fileSize: 128456
        }
      ]),
      reactions: JSON.stringify({
        '👍': 8,
        '📚': 5,
        '🎉': 3
      }),
      is_pinned: true,
      is_edited: false,
      is_deleted: false,
      created_at: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000), // 7 days ago
      updated_at: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000)
    },
    {
      id: update2Id,
      class_id: mathClassId,
      author_id: teacher1Id,
      title: 'Homework: Chapter 3 - Fractions',
      content: 'Please complete exercises 1-15 on pages 45-47 in your textbook. Focus on adding and subtracting fractions with different denominators. Show all your work! Due date is Friday, January 19th. Remember to check your answers using the answer key at the back of the book.',
      update_type: 'homework',
      attachments: JSON.stringify([
        {
          fileName: 'Fraction Worksheet.pdf',
          fileUrl: '/uploads/fraction_worksheet.pdf',
          fileType: 'application/pdf',
          fileSize: 189432
        }
      ]),
      reactions: JSON.stringify({
        '✅': 12,
        '📝': 6
      }),
      is_pinned: false,
      is_edited: false,
      is_deleted: false,
      created_at: new Date(Date.now() - 3 * 24 * 60 * 60 * 1000), // 3 days ago
      updated_at: new Date(Date.now() - 3 * 24 * 60 * 60 * 1000)
    },
    {
      id: update3Id,
      class_id: mathClassId,
      author_id: teacher1Id,
      title: 'Math Test Next Week',
      content: 'We will have our first math test next Thursday, January 25th. The test will cover chapters 1-3: whole numbers, place value, and fractions. Please review your notes and complete the practice problems I handed out in class. Good luck everyone!',
      update_type: 'reminder',
      attachments: JSON.stringify([
        {
          fileName: 'Test Study Guide.pdf',
          fileUrl: '/uploads/test_study_guide_ch1-3.pdf',
          fileType: 'application/pdf',
          fileSize: 156789
        }
      ]),
      reactions: JSON.stringify({
        '📖': 10,
        '💪': 4,
        '😅': 2
      }),
      is_pinned: true,
      is_edited: false,
      is_deleted: false,
      created_at: new Date(Date.now() - 1 * 24 * 60 * 60 * 1000), // 1 day ago
      updated_at: new Date(Date.now() - 1 * 24 * 60 * 60 * 1000)
    },

    // Science Class Updates
    {
      id: update4Id,
      class_id: scienceClassId,
      author_id: teacher1Id,
      title: 'Science Lab Safety Rules',
      content: 'Before we begin our first experiment next week, please review these important safety rules:\n\n1. Always wear safety goggles in the lab\n2. Keep your workspace clean and organized\n3. Never eat or drink in the lab\n4. Report any spills or accidents immediately\n5. Listen to instructions carefully\n\nRemember, safety comes first in our science classroom!',
      update_type: 'announcement',
      attachments: JSON.stringify([
        {
          fileName: 'Lab Safety Rules.pdf',
          fileUrl: '/uploads/lab_safety_rules.pdf',
          fileType: 'application/pdf',
          fileSize: 198765
        },
        {
          fileName: 'Emergency Procedures.pdf',
          fileUrl: '/uploads/emergency_procedures.pdf',
          fileType: 'application/pdf',
          fileSize: 145632
        }
      ]),
      reactions: JSON.stringify({
        '🥽': 15,
        '🔬': 8,
        '👍': 12
      }),
      is_pinned: true,
      is_edited: false,
      is_deleted: false,
      created_at: new Date(Date.now() - 6 * 24 * 60 * 60 * 1000), // 6 days ago
      updated_at: new Date(Date.now() - 6 * 24 * 60 * 60 * 1000)
    },
    {
      id: update5Id,
      class_id: scienceClassId,
      author_id: teacher1Id,
      title: 'Plant Growth Experiment',
      content: 'This week we will start our plant growth experiment! Each student will receive two bean seeds to plant. We will test how different conditions (light vs. dark, water vs. no water) affect plant growth. Make sure to observe your plants daily and record your observations in your science journal.',
      update_type: 'homework',
      attachments: JSON.stringify([
        {
          fileName: 'Observation Chart.pdf',
          fileUrl: '/uploads/plant_observation_chart.pdf',
          fileType: 'application/pdf',
          fileSize: 123456
        },
        {
          fileName: 'Experiment Instructions.pdf',
          fileUrl: '/uploads/plant_experiment_instructions.pdf',
          fileType: 'application/pdf',
          fileSize: 234567
        }
      ]),
      reactions: JSON.stringify({
        '🌱': 18,
        '📊': 7,
        '🧪': 5
      }),
      is_pinned: false,
      is_edited: false,
      is_deleted: false,
      created_at: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000), // 2 days ago
      updated_at: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000)
    },
    {
      id: update6Id,
      class_id: scienceClassId,
      author_id: teacher1Id,
      title: 'Science Fair Participation',
      content: 'The annual school science fair is coming up in March! This is a great opportunity to showcase your scientific thinking and creativity. Participation is optional but highly encouraged. Start thinking about what topic interests you most. I will provide more details and project guidelines next week.',
      update_type: 'event',
      attachments: JSON.stringify([]),
      reactions: JSON.stringify({
        '🏆': 9,
        '💡': 6,
        '🎯': 4
      }),
      is_pinned: false,
      is_edited: false,
      is_deleted: false,
      created_at: new Date(Date.now() - 12 * 60 * 60 * 1000), // 12 hours ago
      updated_at: new Date(Date.now() - 12 * 60 * 60 * 1000)
    },

    // English Literature Class Updates
    {
      id: update7Id,
      class_id: englishClassId,
      author_id: teacher2Id,
      title: 'Course Introduction - English Literature 10B',
      content: 'Welcome to English Literature 10B! This semester we will explore classic and contemporary works including novels, short stories, poetry, and drama. We will focus on developing critical thinking skills, improving writing techniques, and understanding literary devices. Please purchase the required reading list from the school bookstore.',
      update_type: 'announcement',
      attachments: JSON.stringify([
        {
          fileName: 'Required Reading List.pdf',
          fileUrl: '/uploads/reading_list_10b.pdf',
          fileType: 'application/pdf',
          fileSize: 178934
        },
        {
          fileName: 'Course Outline.pdf',
          fileUrl: '/uploads/english_course_outline.pdf',
          fileType: 'application/pdf',
          fileSize: 267845
        }
      ]),
      reactions: JSON.stringify({
        '📚': 14,
        '✍️': 8,
        '👍': 11
      }),
      is_pinned: true,
      is_edited: false,
      is_deleted: false,
      created_at: new Date(Date.now() - 8 * 24 * 60 * 60 * 1000), // 8 days ago
      updated_at: new Date(Date.now() - 8 * 24 * 60 * 60 * 1000)
    },
    {
      id: update8Id,
      class_id: englishClassId,
      author_id: teacher2Id,
      title: 'Reading Assignment: To Kill a Mockingbird - Chapters 1-5',
      content: 'Please read chapters 1-5 of "To Kill a Mockingbird" by Harper Lee for our discussion next Tuesday. As you read, pay attention to the narrator\'s perspective and the setting of the story. Take notes on the main characters and their relationships. We will have a quiz on these chapters next Friday.',
      update_type: 'homework',
      attachments: JSON.stringify([
        {
          fileName: 'Reading Questions Ch 1-5.pdf',
          fileUrl: '/uploads/mockingbird_ch1-5_questions.pdf',
          fileType: 'application/pdf',
          fileSize: 145623
        },
        {
          fileName: 'Character Map Template.pdf',
          fileUrl: '/uploads/character_map_template.pdf',
          fileType: 'application/pdf',
          fileSize: 98765
        }
      ]),
      reactions: JSON.stringify({
        '📖': 16,
        '✏️': 9,
        '🤔': 5
      }),
      is_pinned: false,
      is_edited: false,
      is_deleted: false,
      created_at: new Date(Date.now() - 4 * 24 * 60 * 60 * 1000), // 4 days ago
      updated_at: new Date(Date.now() - 4 * 24 * 60 * 60 * 1000)
    },
    {
      id: update9Id,
      class_id: englishClassId,
      author_id: teacher2Id,
      title: 'Essay Writing Workshop This Friday',
      content: 'We will have a special essay writing workshop this Friday during class time. We will cover thesis statements, paragraph structure, and citation methods. Please bring your laptops or notebooks. This workshop will help you prepare for your first major essay assignment next month.',
      update_type: 'event',
      attachments: JSON.stringify([
        {
          fileName: 'Essay Writing Guide.pdf',
          fileUrl: '/uploads/essay_writing_guide.pdf',
          fileType: 'application/pdf',
          fileSize: 312456
        }
      ]),
      reactions: JSON.stringify({
        '✍️': 13,
        '💻': 8,
        '📝': 10
      }),
      is_pinned: false,
      is_edited: false,
      is_deleted: false,
      created_at: new Date(Date.now() - 18 * 60 * 60 * 1000), // 18 hours ago
      updated_at: new Date(Date.now() - 18 * 60 * 60 * 1000)
    },
    {
      id: update10Id,
      class_id: englishClassId,
      author_id: teacher2Id,
      title: 'Poetry Unit Coming Soon',
      content: 'Next week we will begin our poetry unit! We will study different poetic forms, analyze literary devices, and even try writing our own poems. This unit will help you appreciate the beauty and power of language. Get ready for some creative expression!',
      update_type: 'reminder',
      attachments: JSON.stringify([
        {
          fileName: 'Poetry Terms Glossary.pdf',
          fileUrl: '/uploads/poetry_terms_glossary.pdf',
          fileType: 'application/pdf',
          fileSize: 167890
        }
      ]),
      reactions: JSON.stringify({
        '🎭': 11,
        '📜': 7,
        '🎨': 9
      }),
      is_pinned: false,
      is_edited: false,
      is_deleted: false,
      created_at: new Date(Date.now() - 6 * 60 * 60 * 1000), // 6 hours ago
      updated_at: new Date(Date.now() - 6 * 60 * 60 * 1000)
    }
  ]);

  console.log('Class updates seeded successfully!');
}; 