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
if not os.path.exists(str(harbor_filename)):
    print(str(harbor_filename) + " not found!")
    exit(1)

local_user = input("Enter the username to be created: ")
local_pass = getpass("Enter the password: ")
local_email = "user@gitlab.com"
local_realname = "User Sample"
local_project = input("Enter the project name: ")

print(str(local_user))

# Open console:
tmout=2000
inst_tmout=20000
options = Options()
options.headless = False

# Load files:
harbor_conf = yaml.load(open(str(harbor_filename), "r"), Loader=SafeLoader)

driver = webdriver.Firefox(options=options)
driver.get("https://" + str(harbor_conf["hostname"]))
WebDriverWait(driver,tmout).until(lambda driver: driver.find_element(By.XPATH, '//*[@id="login_username"]')).send_keys("admin")
WebDriverWait(driver,tmout).until(lambda driver: driver.find_element(By.XPATH, '//*[@id="login_password"]')).send_keys(str(harbor_conf["harbor_admin_password"]))
WebDriverWait(driver,tmout).until(lambda driver: driver.find_element(By.XPATH, '//*[@id="log_in"]')).click()

# Add user:
driver.get("https://" + str(harbor_conf["hostname"]) + "/harbor/users")
WebDriverWait(driver,tmout).until(lambda driver: driver.find_element(By.XPATH, '//*[@id="add-new-user"]')).click()
WebDriverWait(driver,tmout).until(lambda driver: driver.find_element(By.XPATH, '//*[@id="username"]')).send_keys(str(local_user))
WebDriverWait(driver,tmout).until(lambda driver: driver.find_element(By.XPATH, '//*[@id="email"]')).send_keys(str(local_email))
WebDriverWait(driver,tmout).until(lambda driver: driver.find_element(By.XPATH, '//*[@id="realname"]')).send_keys(str(local_realname))
WebDriverWait(driver,tmout).until(lambda driver: driver.find_element(By.XPATH, '//*[@id="newPassword"]')).send_keys(str(local_pass))
WebDriverWait(driver,tmout).until(lambda driver: driver.find_element(By.XPATH, '//*[@id="confirmPassword"]')).send_keys(str(local_pass))
WebDriverWait(driver,tmout).until(lambda driver: driver.find_element(By.XPATH, '//*[@id="save-button"]')).click()
driver.close()


# Add project:
driver = webdriver.Firefox(options=options)
driver.get("https://" + str(harbor_conf["hostname"]))
WebDriverWait(driver,tmout).until(lambda driver: driver.find_element(By.XPATH, '//*[@id="login_username"]')).send_keys(str(local_user))
WebDriverWait(driver,tmout).until(lambda driver: driver.find_element(By.XPATH, '//*[@id="login_password"]')).send_keys(str(local_pass))
WebDriverWait(driver,tmout).until(lambda driver: driver.find_element(By.XPATH, '//*[@id="log_in"]')).click()
WebDriverWait(driver,tmout).until(lambda driver: driver.find_element(By.CSS_SELECTOR, 'button.btn-secondary:nth-child(1)')).click()
WebDriverWait(driver,tmout).until(lambda driver: driver.find_element(By.XPATH, '//*[@id="create_project_name"]')).send_keys(str(local_project))
WebDriverWait(driver,tmout).until(lambda driver: driver.find_element(By.XPATH, '//*[@id="new-project-ok"]')).click()
driver.close()
