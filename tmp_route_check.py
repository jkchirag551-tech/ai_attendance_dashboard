import sys
sys.path.insert(0, '.')
import app
application = app.create_app()
for rule in application.url_map.iter_rules():
    print(f'{rule.endpoint:30} {rule.methods} {rule.rule}')
