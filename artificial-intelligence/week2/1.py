class StuData:
    def __init__(self, file_path):
        with open(file_path, 'r') as file:
            self.data = [ line.split() for line in file.readlines() ]
            for line in self.data:
                line[3] = int(line[3])

    def AddData(self, name, stuid, gender, age):
        self.data.append([ name, stuid, gender, age ])

data = StuData('student_data.txt')
print(data.data)
