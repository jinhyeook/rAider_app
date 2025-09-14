# Flask 서버에 추가할 코드들

# 1. 회원가입 API 수정 (personal_number 필드 추가)
@app.route('/api/auth/register', methods=['POST'])
def register():
    """회원가입 API"""
    try:
        data = request.get_json()
        
        # 필수 필드 검증 (ssn 추가)
        required_fields = ['username', 'email', 'password', 'phone', 'birth', 'ssn', 'driver_license']
        for field in required_fields:
            if not data.get(field):
                return jsonify({'error': f'{field}는 필수 입력 항목입니다.'}), 400
        
        # 이메일 형식 검증
        if not is_valid_email(data['email']):
            return jsonify({'error': '올바른 이메일 형식이 아닙니다.'}), 400
        
        # 전화번호 형식 검증
        if not is_valid_phone(data['phone']):
            return jsonify({'error': '올바른 전화번호 형식이 아닙니다. (예: 010-1234-5678)'}), 400
        
        # 생년월일 형식 검증
        if not is_valid_birth(data['birth']):
            return jsonify({'error': '올바른 생년월일 형식이 아닙니다. (예: 1990-01-01)'}), 400
        
        # 주민번호 형식 검증 (새로 추가)
        if not is_valid_ssn(data['ssn']):
            return jsonify({'error': '올바른 주민번호 형식이 아닙니다. (예: 901201-1234567)'}), 400
        
        # 비밀번호 길이 검증
        if len(data['password']) < 6:
            return jsonify({'error': '비밀번호는 최소 6자 이상이어야 합니다.'}), 400
        
        # 이메일 중복 검사
        email_check_sql = text("SELECT COUNT(*) FROM USER_INFO WHERE email = :email")
        email_exists = db.session.execute(email_check_sql, {'email': data['email']}).scalar()
        
        if email_exists > 0:
            return jsonify({'error': '이미 사용 중인 이메일입니다.'}), 409
        
        # 주민번호 중복 검사 (새로 추가)
        ssn_check_sql = text("SELECT COUNT(*) FROM USER_INFO WHERE personal_number = :ssn")
        ssn_exists = db.session.execute(ssn_check_sql, {'ssn': data['ssn']}).scalar()
        
        if ssn_exists > 0:
            return jsonify({'error': '이미 사용 중인 주민번호입니다.'}), 409
        
        # 사용자 ID 생성
        user_id = f"user_{uuid.uuid4().hex[:8]}"
        
        # 기존 데이터와 호환성을 위해 평문으로 저장
        plain_password = data['password']
        
        # 나이 계산
        birth_date = datetime.strptime(data['birth'], '%Y-%m-%d')
        today = datetime.now()
        age = today.year - birth_date.year - ((today.month, today.day) < (birth_date.month, birth_date.day))
        
        # 사용자 정보 삽입 (personal_number 컬럼 추가)
        insert_sql = text("""
            INSERT INTO USER_INFO (USER_ID, user_pw, name, email, phone, birth, age, sex, personal_number, driver_license_number, sign_up_date, is_delete)
            VALUES (:user_id, :password, :name, :email, :phone, :birth, :age, :sex, :ssn, :driver_license, :sign_up_date, 0)
        """)
        
        db.session.execute(insert_sql, {
            'user_id': user_id,
            'name': data['username'],
            'email': data['email'],
            'password': plain_password,
            'phone': data['phone'],
            'birth': data['birth'],
            'age': age,
            'sex': data.get('sex', 'M'),  # 기본값: 남성
            'ssn': data['ssn'],  # 주민번호 추가
            'driver_license': data['driver_license'],
            'sign_up_date': datetime.now()
        })
        
        db.session.commit()
        
        return jsonify({
            'message': '회원가입이 완료되었습니다.',
            'user_id': user_id,
            'username': data['username']
        }), 201
        
    except Exception as e:
        db.session.rollback()
        print(f"회원가입 오류: {str(e)}")
        return jsonify({'error': '회원가입 중 오류가 발생했습니다.'}), 500

# 2. 주민번호 유효성 검사 함수 추가
def is_valid_ssn(ssn):
    """주민번호 형식 유효성 검사 (XXXXXX-XXXXXXX)"""
    pattern = r'^\d{6}-\d{7}$'
    if not re.match(pattern, ssn):
        return False
    
    # 주민번호 체크섬 검증 (간단한 버전)
    try:
        # 앞 6자리 (생년월일)
        birth_part = ssn[:6]
        # 뒤 7자리 (성별코드 + 지역코드 + 일련번호 + 체크섬)
        id_part = ssn[7:]
        
        # 생년월일 유효성 검사
        year = int(birth_part[:2])
        month = int(birth_part[2:4])
        day = int(birth_part[4:6])
        
        # 1900년대 또는 2000년대 판단
        if year >= 0 and year <= 99:
            if int(id_part[0]) <= 2:  # 1, 2로 시작하면 1900년대
                year += 1900
            else:  # 3, 4로 시작하면 2000년대
                year += 2000
        
        # 날짜 유효성 검사
        from datetime import datetime
        datetime(year, month, day)
        
        return True
    except (ValueError, IndexError):
        return False

# 3. 주민번호 중복 확인 API 추가
@app.route('/api/auth/check-ssn', methods=['POST'])
def check_ssn():
    """주민번호 중복 확인 API"""
    try:
        data = request.get_json()
        ssn = data.get('ssn')
        
        if not ssn:
            return jsonify({'error': '주민번호를 입력해주세요.'}), 400
        
        if not is_valid_ssn(ssn):
            return jsonify({'error': '올바른 주민번호 형식이 아닙니다. (예: 901201-1234567)'}), 400
        
        # 주민번호 중복 검사
        ssn_check_sql = text("SELECT COUNT(*) FROM USER_INFO WHERE personal_number = :ssn")
        ssn_exists = db.session.execute(ssn_check_sql, {'ssn': ssn}).scalar()
        
        if ssn_exists > 0:
            return jsonify({'available': False, 'message': '이미 사용 중인 주민번호입니다.'}), 409
        else:
            return jsonify({'available': True, 'message': '사용 가능한 주민번호입니다.'}), 200
            
    except Exception as e:
        print(f"주민번호 확인 오류: {str(e)}")
        return jsonify({'error': '주민번호 확인 중 오류가 발생했습니다.'}), 500

# 4. 사용자 정보 조회 API에 personal_number 추가
@app.route('/api/user-info/<user_id>', methods=['GET'])
def get_user_info(user_id):
    """특정 사용자의 상세 정보 조회 API (신고 횟수 포함)"""
    try:
        # 사용자 정보와 신고 횟수를 함께 조회
        user_info_sql = text("""
            SELECT 
                u.USER_ID,
                u.name,
                u.email,
                u.phone,
                u.birth,
                u.age,
                u.personal_number,
                u.driver_license_number,
                COALESCE(r.report_count, 0) as report_count
            FROM USER_INFO u
            LEFT JOIN (
                SELECT REPORTED_USER_ID, COUNT(*) as report_count
                FROM REPORT_LOG
                WHERE REPORTED_USER_ID = :user_id
                GROUP BY REPORTED_USER_ID
            ) r ON u.USER_ID = r.REPORTED_USER_ID
            WHERE u.USER_ID = :user_id AND u.is_delete = 0
        """)
        
        user = db.session.execute(user_info_sql, {'user_id': user_id}).mappings().first()
        
        if not user:
            return jsonify({'error': '사용자를 찾을 수 없습니다.'}), 404
        
        # 사용자 정보 반환 (신고 횟수 포함)
        return jsonify({
            'USER_ID': user['USER_ID'],
            'name': user['name'],
            'email': user['email'],
            'phone': user['phone'],
            'birth': user['birth'].isoformat() if user['birth'] else None,
            'age': user['age'],
            'personal_number': user['personal_number'],  # 주민번호 추가
            'driver_license': user['driver_license_number'],  # 운전면허증 번호 추가
            'report_count': int(user['report_count'])
        }), 200
        
    except Exception as e:
        print(f"사용자 정보 조회 오류: {str(e)}")
        return jsonify({'error': '사용자 정보 조회 중 오류가 발생했습니다.'}), 500

# 5. 사용자 정보 업데이트 API에 personal_number 추가
@app.route('/api/user-info/<user_id>', methods=['PUT'])
def update_user_info(user_id):
    """사용자 정보 업데이트 API"""
    try:
        data = request.get_json()
        
        # 업데이트 가능한 필드들
        update_fields = []
        params = {'user_id': user_id}
        
        if 'name' in data:
            update_fields.append('name = :name')
            params['name'] = data['name']
        
        if 'phone' in data:
            # 전화번호 형식 검증
            if not is_valid_phone(data['phone']):
                return jsonify({'error': '올바른 전화번호 형식이 아닙니다. (예: 010-1234-5678)'}), 400
            update_fields.append('phone = :phone')
            params['phone'] = data['phone']
        
        if 'birth' in data:
            # 생년월일 형식 검증
            if not is_valid_birth(data['birth']):
                return jsonify({'error': '올바른 생년월일 형식이 아닙니다. (예: 1990-01-01)'}), 400
            
            # 나이 계산
            birth_date = datetime.strptime(data['birth'], '%Y-%m-%d')
            today = datetime.now()
            age = today.year - birth_date.year - ((today.month, today.day) < (birth_date.month, birth_date.day))
            
            update_fields.append('birth = :birth')
            update_fields.append('age = :age')
            params['birth'] = data['birth']
            params['age'] = age
        
        if 'personal_number' in data:
            # 주민번호 형식 검증
            if not is_valid_ssn(data['personal_number']):
                return jsonify({'error': '올바른 주민번호 형식이 아닙니다. (예: 901201-1234567)'}), 400
            
            # 주민번호 중복 검사 (본인 제외)
            ssn_check_sql = text("SELECT COUNT(*) FROM USER_INFO WHERE personal_number = :ssn AND USER_ID != :user_id")
            ssn_exists = db.session.execute(ssn_check_sql, {
                'ssn': data['personal_number'],
                'user_id': user_id
            }).scalar()
            
            if ssn_exists > 0:
                return jsonify({'error': '이미 사용 중인 주민번호입니다.'}), 409
            
            update_fields.append('personal_number = :personal_number')
            params['personal_number'] = data['personal_number']
        
        if not update_fields:
            return jsonify({'error': '업데이트할 정보가 없습니다.'}), 400
        
        # 사용자 정보 업데이트
        update_sql = text(f"""
            UPDATE USER_INFO 
            SET {', '.join(update_fields)}
            WHERE USER_ID = :user_id AND is_delete = 0
        """)
        
        result = db.session.execute(update_sql, params)
        db.session.commit()
        
        if result.rowcount > 0:
            return jsonify({'message': '사용자 정보가 성공적으로 업데이트되었습니다.'}), 200
        else:
            return jsonify({'error': '사용자를 찾을 수 없습니다.'}), 404
            
    except Exception as e:
        db.session.rollback()
        print(f"사용자 정보 업데이트 오류: {str(e)}")
        return jsonify({'error': '사용자 정보 업데이트 중 오류가 발생했습니다.'}), 500

# 6. 데이터베이스 스키마 업데이트 (personal_number 컬럼 추가)
def add_personal_number_column():
    """USER_INFO 테이블에 personal_number 컬럼 추가"""
    try:
        # personal_number 컬럼이 이미 존재하는지 확인
        check_column_sql = text("""
            SELECT COUNT(*) 
            FROM INFORMATION_SCHEMA.COLUMNS 
            WHERE TABLE_SCHEMA = DATABASE() 
            AND TABLE_NAME = 'USER_INFO' 
            AND COLUMN_NAME = 'personal_number'
        """)
        
        column_exists = db.session.execute(check_column_sql).scalar()
        
        if column_exists == 0:
            # personal_number 컬럼 추가
            add_column_sql = text("""
                ALTER TABLE USER_INFO 
                ADD COLUMN personal_number VARCHAR(14) UNIQUE COMMENT '주민번호'
            """)
            
            db.session.execute(add_column_sql)
            db.session.commit()
            print("personal_number 컬럼이 성공적으로 추가되었습니다.")
        else:
            print("personal_number 컬럼이 이미 존재합니다.")
            
    except Exception as e:
        print(f"personal_number 컬럼 추가 오류: {str(e)}")
        db.session.rollback()

# 7. 앱 시작 시 컬럼 추가 실행
if __name__ == '__main__':
    # 데이터베이스 스키마 업데이트
    add_personal_number_column()
    
    app.run(debug=True, host='0.0.0.0', port=5000)
