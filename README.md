# Jenkins CI/CD Lab

A small Flask app with a Jenkins pipeline that builds, tests, and deploys it in Docker on AWS EC2, and a second pipeline that publishes the image to Docker Hub. The EC2 instance is provisioned with Terraform.

## What's here

| Path | Purpose |
|---|---|
| `app.py` | Flask app that returns "Hello, Jenkins!" |
| `test_app.py` | Two pytest unit tests |
| `requirements.txt` | Flask and pytest |
| `Dockerfile` | Packages the app into a Python 3.12 image |
| `Jenkinsfile` | Build, test, and deploy pipeline |
| `Jenkinsfile-dockerhub` | Build, test, and push to Docker Hub pipeline |
| `terraform/` | EC2 instance, key pair, and security group |

## How it fits together

```
GitHub repo  -->  Jenkins (Docker container on EC2)  -->  Docker on the same EC2 host
                         |                                        |
                         |                                 app on port 80
                         +-->  Docker Hub (gflounder/jenkins-demo)
```

Jenkins runs in a container with the host's Docker socket mounted, so `docker build` and `docker run` in the pipelines use the EC2 host's Docker.

## Pipelines

**Jenkinsfile** (job `jenkins-demo-pipeline`)
1. **Build:** `docker build`, tagged with the Jenkins build number.
2. **Test:** runs pytest inside the new image. A failure stops the pipeline.
3. **Deploy:** replaces the running app container and maps port 80 to the app's port 5000.
4. **post:** prints the app's public URL on success.

**Jenkinsfile-dockerhub** (job `jenkins-dockerhub-pipeline`)
1. **Build Image:** tags the image with the build number and `latest`.
2. **Test Image:** runs pytest before anything is published.
3. **Push to Docker Hub:** logs in with a token from Jenkins credentials (`docker-hub-creds`) using `--password-stdin`, then pushes both tags.
4. **post:** always logs out.

Both jobs use "Pipeline script from SCM" pointed at this repo, branch `*/main`, with the matching Script Path.

## Infrastructure

`terraform/` creates:
- **aws_key_pair** from a locally generated ed25519 public key
- **aws_security_group** allowing SSH and 8080 from the operator's IP only, and 80 from anywhere
- **aws_instance** (t2.micro, Ubuntu 24.04, 20 GB gp3) with a `user_data` script that adds 2 GB of swap so Jenkins runs in 1 GB of RAM

The Ubuntu AMI is looked up from Canonical's public SSM parameter instead of a hardcoded ID.

```bash
cd terraform
ssh-keygen -t ed25519 -f ./jenkins-key
terraform init
terraform apply
```

## Running Jenkins on the instance

```bash
docker run -d --name jenkins \
  -p 8080:8080 -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -u root \
  jenkins/jenkins:lts

docker exec jenkins mkdir -p /usr/libexec/docker/cli-plugins
docker cp /usr/bin/docker jenkins:/usr/bin/docker
docker cp /usr/libexec/docker/cli-plugins/docker-buildx jenkins:/usr/libexec/docker/cli-plugins/docker-buildx
```

Mounting the Docker socket and running as root is a lab shortcut. In production, builds would run on dedicated agents.

## Problems solved along the way

- **Nested `success` block:** an edit left one `success { }` inside another, which Jenkins reported as `No such DSL method 'success'`. `success` only belongs directly inside `post`.
- **Wrong Jenkinsfile running:** a new job defaulted its Script Path to `Jenkinsfile`. The `Obtained ... from git` line at the top of the console log shows which file a job actually used.
- **Credential ID mismatch:** Jenkins looks up credentials by exact ID and IDs can't be edited after creation, so the Jenkinsfile was updated to match.
- **Uppercase username:** Docker image names must be lowercase.

## Security notes

- No keys, tokens, or Terraform state are committed (see `.gitignore`).
- The Docker Hub token lives only in Jenkins credentials and is masked in build logs.
