#!/usr/bin/python

from selenium import webdriver
from selenium.webdriver import ActionChains
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support.ui import Select
from selenium.webdriver.common.by import By
from selenium.webdriver.firefox.options import Options
import time
import yaml
from yaml.loader import SafeLoader
import mouse
from getpass import getpass
import os
from sys import exit

harbor_filename = "files" + str(os.sep) + "harbor.yml"
users_filename = "harbor_users.yml"

if not os.path.exists(str(harbor_filename)):
    print(str(harbor_filename) + " not found!")
    exit(1)

if not os.path.exists(str(users_filename)):
    print(str(users_filename) + " not found!")
    exit(1)


# Open console:
tmout=2000
inst_tmout=20000
options = Options()

options.add_argument('-headless')

# Load files:
harbor_conf = yaml.load(open(str(harbor_filename), "r"), Loader=SafeLoader)
user_conf = yaml.load(open(str(users_filename), "r"), Loader=SafeLoader)

# Add users:
while True:
    driver = webdriver.Firefox(options=options)
    driver.get("https://" + str(harbor_conf["hostname"]))    
    WebDriverWait(driver,tmout).until(lambda driver: driver.find_element(By.XPATH, '//*[@id="login_username"]')).send_keys("admin")
    WebDriverWait(driver,tmout).until(lambda driver: driver.find_element(By.XPATH, '//*[@id="login_password"]')).send_keys(str(harbor_conf["harbor_admin_password"]))
    WebDriverWait(driver,tmout).until(lambda driver: driver.find_element(By.XPATH, '//*[@id="log_in"]')).click()
    time.sleep(2)
    try:
        WebDriverWait(driver,2).until(lambda driver: driver.find_element(By.XPATH, '//*[@id="login_username"]'))
        driver.close()
        driver.quit()        
    except:    
        break

for u in user_conf["users"]:
    print(f"Creating user {u['user']}...")
    driver.get("https://" + str(harbor_conf["hostname"]) + "/harbor/users")
    WebDriverWait(driver,tmout).until(lambda driver: driver.find_element(By.XPATH, '//*[@id="add-new-user"]')).click()
    WebDriverWait(driver,tmout).until(lambda driver: driver.find_element(By.XPATH, '//*[@id="username"]')).send_keys(str(u["user"]))
    WebDriverWait(driver,tmout).until(lambda driver: driver.find_element(By.XPATH, '//*[@id="email"]')).send_keys(str(u["email"]))
    WebDriverWait(driver,tmout).until(lambda driver: driver.find_element(By.XPATH, '//*[@id="realname"]')).send_keys(str(u["real_name"]))
    WebDriverWait(driver,tmout).until(lambda driver: driver.find_element(By.XPATH, '//*[@id="newPassword"]')).send_keys(str(u["password"]))
    WebDriverWait(driver,tmout).until(lambda driver: driver.find_element(By.XPATH, '//*[@id="confirmPassword"]')).send_keys(str(u["password"]))
    WebDriverWait(driver,tmout).until(lambda driver: driver.find_element(By.XPATH, '//*[@id="save-button"]')).click()

driver.close()
driver.quit()

# Add project:
for u in user_conf["users"]:
    for p in u["projects"]:
        print(f"Adding project {p} for user {u['user']}")
        driver = webdriver.Firefox(options=options)
        driver.get("https://" + str(harbor_conf["hostname"]))
        WebDriverWait(driver,tmout).until(lambda driver: driver.find_element(By.XPATH, '//*[@id="login_username"]')).send_keys(str(u["user"]))
        WebDriverWait(driver,tmout).until(lambda driver: driver.find_element(By.XPATH, '//*[@id="login_password"]')).send_keys(str(u["password"]))
        WebDriverWait(driver,tmout).until(lambda driver: driver.find_element(By.XPATH, '//*[@id="log_in"]')).click()
        time.sleep(5)
        WebDriverWait(driver,tmout).until(lambda driver: driver.find_element(By.CSS_SELECTOR, 'button.btn-secondary:nth-child(1)')).click()
        WebDriverWait(driver,tmout).until(lambda driver: driver.find_element(By.XPATH, '//*[@id="create_project_name"]')).send_keys(str(p))
        WebDriverWait(driver,tmout).until(lambda driver: driver.find_element(By.XPATH, '//*[@id="new-project-ok"]')).click()
        driver.close()
        driver.quit()
