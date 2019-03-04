Basic tools for backuping to s3
===============================

[![Project is](https://img.shields.io/badge/Project%20is-fantastic-ff69b4.svg)](https://github.com/Bessonov/s3-backup)
[![License](http://img.shields.io/:license-MIT-blue.svg)](https://raw.githubusercontent.com/Bessonov/s3-backup/master/LICENSE)

In most cases you can stream to s3 and don't need temp files!

It's intended for usage with kubernetes, but you can use it with docker too. Get current version of image from [Docker Hub](https://hub.docker.com/r/bessonov/s3-backup/tags). Although there is `latest` version of image, only versioned versions should be used.

## Table of Contents
- [Backup mongodb compatible database](#backup-mongodb-compatible-database)
- [Backup mysql compatible database](#backup-mysql-compatible-database)
- [Backup files and usage with docker](#backup-files-and-usage-with-docker)
- [Expiration of old backups](#expiration-of-old-backups)
- [Symmetric encryption of backups](#symmetric-encryption-of-backups)

## Backup mongodb compatible database

Example usage for mongodb:

```
apiVersion: batch/v1beta1
kind: CronJob
metadata:
  name: mongodump
spec:
  schedule: "0 0 * * *"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 2
  failedJobsHistoryLimit: 2
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: Never
          containers:
          - name: mongodump
            image: bessonov/s3-backup:version
            command:
            - sh
            - -c
            - time mongodump --uri=$MONGODB_URI --archive --gzip | aws s3 cp - s3://your-bucket/path/file.gz
            env:
              - name: MONGODB_URI
                valueFrom:
                  secretKeyRef:
                    name: mongodb-aws-backup
                    key: MONGODB_URI
              - name: AWS_ACCESS_KEY_ID
                valueFrom:
                  secretKeyRef:
                    name: mongodb-aws-backup
                    key: AWS_ACCESS_KEY_ID
              - name: AWS_SECRET_ACCESS_KEY
                valueFrom:
                  secretKeyRef:
                    name: mongodb-aws-backup
                    key: AWS_SECRET_ACCESS_KEY
              - name: AWS_DEFAULT_REGION
                valueFrom:
                  secretKeyRef:
                    name: mongodb-aws-backup
                    key: AWS_DEFAULT_REGION
```

## Backup mysql compatible database

Example usage for mariadb/mysql:

```
apiVersion: batch/v1beta1
kind: CronJob
metadata:
  name: mariadbdump
spec:
  schedule: "0 0 * * *"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 2
  failedJobsHistoryLimit: 2
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: Never
          containers:
          - name: mongodump
            image: bessonov/s3-backup:version
            command:
            - sh
            - -c
            - exit_code=0;
              databases=$(mysql -h $DB_SERVER -P $DB_PORT -u"$DB_USER" -p"$DB_PASS" -N -B -e 'SELECT `schema_name` from INFORMATION_SCHEMA.SCHEMATA WHERE `schema_name` NOT IN("information_schema", "mysql", "performance_schema")');
              exit_code=`expr $? + $exit_code`;
              for db in $databases; do
                echo "backup ${db}";
                time mysqldump -h $DB_SERVER -P $DB_PORT -u"$DB_USER" -p"$DB_PASS" --databases ${db} --default-character-set=utf8mb4 | gzip -9 | aws s3 cp - s3://your-bucket/path/backup_${db}.gz;
                exit_code=`expr $? + $exit_code`;
              done;
              exit $exit_code
            env:
              - name: DB_SERVER
                valueFrom:
                  secretKeyRef:
                    name: mariadb-aws-backup
                    key: DB_SERVER
              - name: DB_PORT
                valueFrom:
                  secretKeyRef:
                    name: mariadb-aws-backup
                    key: DB_PORT
              - name: DB_USER
                valueFrom:
                  secretKeyRef:
                    name: mariadb-aws-backup
                    key: DB_USER
              - name: DB_PASS
                valueFrom:
                  secretKeyRef:
                    name: mariadb-aws-backup
                    key: DB_PASS
              - name: AWS_ACCESS_KEY_ID
                valueFrom:
                  secretKeyRef:
                    name: mariadb-aws-backup
                    key: AWS_ACCESS_KEY_ID
              - name: AWS_SECRET_ACCESS_KEY
                valueFrom:
                  secretKeyRef:
                    name: mariadb-aws-backup
                    key: AWS_SECRET_ACCESS_KEY
              - name: AWS_DEFAULT_REGION
                valueFrom:
                  secretKeyRef:
                    name: mariadb-aws-backup
                    key: AWS_DEFAULT_REGION
```

## Backup files and usage with docker

You can backup also files. For example backup *.env files with crontab and docker:

```
0 3 * * * docker run --rm --env-file=/root/backup-secret.env -v /backup/folder:/data:ro -u root bessonov/s3-backup:version sh -c 'time find /data -maxdepth 1 -name "*.env" | tar -cvz --files-from - | openssl enc -aes128 -pbkdf2 -pass pass:"$BACKUP_PASS" | aws s3 cp - s3://your-bucket/path/backup-env-files.gz'
```

## Expiration of old backups

A possible CloudFormation definition with expiration of old backups could be:
```
Resources:
  BackupServiceS3Bucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: backup
      VersioningConfiguration:
        Status: Enabled
      LifecycleConfiguration:
        Rules:
          # clean up old unfinished uploads
          - AbortIncompleteMultipartUpload:
              DaysAfterInitiation: 7
            Status: Enabled
          # hold removed files for 14 days
          - NoncurrentVersionExpirationInDays: 14
            Status: Enabled
```

## Symmetric encryption of backups

Image includes openssl for encryption or certificate validation. Example usage:

```
mongodump --uri=$MONGODB_URI --archive --gzip | openssl enc -aes128 -pbkdf2 -pass pass:"$SECRET" | aws s3 cp - s3://your-bucket/path/file.gz
```

Be aware, that `$SECRET` is leaked through `ps` and other tools if it's done this way. PR's for better way and for asymmetric encryption are welcome.

To decrypt use `openssl enc -d -aes128 -pbkdf2 -pass pass:"$SECRET"`.

License
-------

The MIT License (MIT)

Copyright (c) 2019, Anton Bessonov

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
