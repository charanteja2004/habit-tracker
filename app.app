from flask import Flask,request,redirect,render_template,session
from datetime import date
from flask_sqlalchemy import SQLAlchemy
from werkzeug.security import generate_password_hash,check_password_hash

app=Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI']='sqlite:///user.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['SECRET_KEY'] = 'mysecretkey'

db=SQLAlchemy(app)

class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    email=db.Column(db.String(120),nullable=False)
    hash_pass=db.Column(db.String(120),nullable=False)
    habits=db.relationship('Habit',backref='user',lazy=True)

class Habit(db.Model):
    id = db.Column(db.Integer,primary_key=True)
    name=db.Column(db.String(120),nullable=False)
    user_id=db.Column(db.Integer,db.ForeignKey('user.id'),nullable=False)
    checkins=db.relationship('Checkins',backref='habit',lazy=True)

class Checkins(db.Model):
    id = db.Column(db.Integer,primary_key=True)
    date=db.Column(db.Date,nullable=True)
    habit_id=db.Column(db.Integer,db.ForeignKey('habit.id'),nullable=False)
    

with app.app_context():
    db.create_all()   

@app.route("/register",methods=['POST','GET'])
def register():
    if request.method == 'POST':
        email=request.form.get('email')
        password=request.form.get('password')

        if User.query.filter_by(email=email).first():
            return "Email already exists"
        hash_pass=generate_password_hash(password)
        user=User(email=email,hash_pass=hash_pass)
        db.session.add(user)
        db.session.commit()
        return redirect('/login')
    return render_template('register.html')


@app.route('/login',methods=['POST','GET'])
def login():
    if request.method=='POST':
        email=request.form.get('email')
        password=request.form.get('password')
        user=User.query.filter_by(email=email).first()
        if user and check_password_hash(user.hash_pass,password):
            session['user_id']=user.id
            return redirect('/')
    return render_template('login.html')

@app.route('/logout')
def logout():
    session.pop('user_id', None)
    return redirect('/login')


@app.route('/',methods=['POST','GET'])
def index():
    if 'user_id' not in session:
        return redirect('/login')
    user=User.query.get(session['user_id'])

    if request.method=='POST':
        habit_name=request.form.get('habit')
        if habit_name:
            habit=Habit(name=habit_name,user_id=user.id)
            db.session.add(habit)
            db.session.commit()
            return redirect('/')

    habits=Habit.query.filter_by(user_id=user.id).all()
    today=date.today()

    checkin_status={}
    for habit in habits:
        checkin=Checkins.query.filter_by(habit_id=habit.id,date=today).first()
        checkin_status[habit.id]=bool(checkin)

    return render_template('index.html',habits=habits,checkin_status=checkin_status,today=today)

@app.route('/checkin/<int:habit_id>',methods=['POST'])
def checkin(habit_id):
    if 'user_id' not in session:
        return redirect('/login')
    
    habit=Habit.query.get_or_404(habit_id)
    today=date.today()

    existing=Checkins.query.filter_by(habit_id=habit.id,date=today).first()

    if existing:
        db.session.delete(existing)
    else :
        checkin=Checkins(habit_id=habit.id,date=today)
        db.session.add(checkin)
    db.session.commit()
    return redirect('/')

@app.route('/delete/<int:habit_id>',methods=['POST'])
def delete_habit(habit_id):
    if 'user_id' not in session:
        return redirect('/login')

    habit=Habit.query.get_or_404(habit_id)

    if habit.user_id!=session['user_id']:
        return "Unauthorized", 403

    db.session.delete(habit)
    db.session.commit()
    return redirect('/')

if __name__=='__main__':
    app.run(debug=True)